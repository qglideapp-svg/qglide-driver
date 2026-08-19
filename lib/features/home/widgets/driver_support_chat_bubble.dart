import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app_fonts.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_responsive.dart';
import '../../../config/app_strings.dart';
import '../../../config/dashboard_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../profile/models/support_ticket.dart';
import '../../support/support_chat_loader.dart';
import '../../support/support_chat_widgets.dart';

class DriverSupportChatBubble extends StatefulWidget {
  const DriverSupportChatBubble({super.key});

  @override
  State<DriverSupportChatBubble> createState() =>
      _DriverSupportChatBubbleState();
}

class _DriverSupportChatBubbleState extends State<DriverSupportChatBubble>
    with SingleTickerProviderStateMixin {
  static const _pollInterval = Duration(seconds: 8);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <SupportChatMessage>[];

  late final AnimationController _expandController;

  Timer? _pollTimer;
  var _isOpen = false;
  var _isLoading = false;
  var _isFetching = false;
  var _isSending = false;
  var _canReply = true;
  var _hasLoadedSession = false;
  var _unreadCount = 0;
  String? _loadError;
  String? _activeTicketId;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    unawaited(_refreshUnreadBadge());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _expandController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_isOpen && mounted) {
        unawaited(_loadMessages(markUnreadAsRead: false, silent: true));
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refreshUnreadBadge() async {
    final session = await SupportChatLoader.loadActiveSession();
    if (!mounted) return;
    setState(() => _unreadCount = session.unreadNotificationIds.length);
  }

  Future<void> _toggleOpen() async {
    final opening = !_isOpen;
    setState(() => _isOpen = opening);
    if (opening) {
      await _expandController.forward();
      _startPolling();
      if (!_hasLoadedSession) {
        await _loadSupportSession();
      } else {
        await _loadMessages(markUnreadAsRead: true);
      }
    } else {
      _stopPolling();
      await _expandController.reverse();
    }
  }

  Future<void> _close() async {
    if (!_isOpen) return;
    _stopPolling();
    setState(() => _isOpen = false);
    await _expandController.reverse();
  }

  Future<void> _loadMessages({
    bool markUnreadAsRead = true,
    bool silent = false,
  }) async {
    if (_isFetching) return;
    _isFetching = true;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _loadError = null;
        _canReply = true;
      });
    }

    final session = await SupportChatLoader.loadActiveSession();

    if (!mounted) {
      _isFetching = false;
      return;
    }

    if (!silent &&
        session.messages.isEmpty &&
        session.unreadNotificationIds.isEmpty) {
      final probe = await AuthService.getAdminSystemNotifications(limit: 1);
      if (!mounted) {
        _isFetching = false;
        return;
      }
      if (probe['success'] != true) {
        setState(() {
          _isLoading = false;
          _loadError = AuthService.extractErrorMessage(
            probe,
            fallback: AppStrings.current().errLoadNotifications,
          );
        });
        _isFetching = false;
        return;
      }
    }

    if (markUnreadAsRead) {
      await SupportChatLoader.markUnreadAsRead(session.unreadNotificationIds);
      if (mounted) setState(() => _unreadCount = 0);
    } else if (mounted) {
      setState(() => _unreadCount = session.unreadNotificationIds.length);
    }

    if (!mounted) {
      _isFetching = false;
      return;
    }

    final previousLength = _messages.length;
    setState(() {
      _isLoading = false;
      _loadError = null;
      _messages
        ..clear()
        ..addAll(session.messages);
      _activeTicketId = session.activeTicketId;
      _canReply = session.canReply;
    });

    if (_messages.length > previousLength || markUnreadAsRead) {
      _scrollToBottom();
    }

    _isFetching = false;
  }

  Future<void> _loadSupportSession() async {
    await _loadMessages(markUnreadAsRead: true);
    if (mounted) {
      setState(() => _hasLoadedSession = true);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || !_canReply) return;

    setState(() => _isSending = true);

    if (_activeTicketId == null) {
      final subject = text.length > 60 ? '${text.substring(0, 57)}...' : text;
      final response = await AuthService.createSupportTicket(
        subject: subject,
        description: text,
        category: DriverSupportTicketCategory.defaultValue,
      );

      if (!mounted) return;

      if (response['success'] != true) {
        setState(() => _isSending = false);
        _showError(
          AuthService.extractErrorMessage(
            response,
            fallback: AppStrings.current().errCreateTicket,
          ),
        );
        return;
      }

      final ticket = AuthService.extractCreatedSupportTicket(response);
      if (ticket == null || ticket.id.isEmpty) {
        setState(() => _isSending = false);
        _showError(AppStrings.current().errCreateTicket);
        return;
      }

      _activeTicketId = ticket.id;
      _messageController.clear();
      setState(() => _isSending = false);
      await _loadMessages(markUnreadAsRead: false);
      return;
    }

    final optimisticId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = SupportChatMessage(
      id: optimisticId,
      message: text,
      isFromDriver: true,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(optimistic);
    });
    _messageController.clear();
    _scrollToBottom();

    final response = await AuthService.replyToSupportTicket(
      ticketId: _activeTicketId!,
      message: text,
    );

    if (!mounted) return;

    if (response['success'] != true) {
      setState(() {
        _messages.removeWhere((message) => message.id == optimisticId);
        _isSending = false;
      });
      _showError(
        AuthService.extractErrorMessage(
          response,
          fallback: AppStrings.current().errSendReply,
        ),
      );
      return;
    }

    setState(() => _isSending = false);
    await _loadMessages(markUnreadAsRead: false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _openChatHistory() {
    unawaited(_close());
    Navigator.of(context).pushNamed(AppRoutes.supportChatHistory);
  }

  double _panelHeightWithKeyboard({
    required double basePanelHeight,
    required double keyboardInset,
    required double fabSize,
    required AppResponsive r,
  }) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final availableHeight = MediaQuery.sizeOf(context).height -
        keyboardInset -
        viewPadding.top -
        fabSize -
        r.gap(24);
    final maxPanelHeight = availableHeight - r.h(120);
    if (maxPanelHeight <= 0) {
      return basePanelHeight.clamp(180.0, 240.0);
    }
    return basePanelHeight.clamp(180.0, maxPanelHeight);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final panelWidth = (r.width * 0.88).clamp(280.0, 380.0);
    final fabSize = r.w(56).clamp(52.0, 60.0);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final basePanelHeight = r.h(420).clamp(320.0, 480.0);
    final panelHeight = keyboardInset > 0
        ? _panelHeightWithKeyboard(
            basePanelHeight: basePanelHeight,
            keyboardInset: keyboardInset,
            fabSize: fabSize,
            r: r,
          )
        : basePanelHeight;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRect(
            child: Align(
              alignment: Alignment.bottomRight,
              heightFactor: _expandController.value,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _expandController,
                  curve: Curves.easeOut,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _expandController,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: Container(
                    width: panelWidth,
                    height: panelHeight,
                    margin: EdgeInsets.only(bottom: r.gap(12)),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: dashboard.surface,
                      borderRadius: BorderRadius.circular(r.borderRadiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: r.gap(24),
                          offset: Offset(0, r.gap(8)),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SupportChatHeader(
                          compact: true,
                          onClose: () => unawaited(_close()),
                          onViewHistory: _openChatHistory,
                        ),
                        Expanded(
                          child: SupportChatMessageList(
                            scrollController: _scrollController,
                            messages: _messages,
                            isLoading: _isLoading,
                            loadError: _loadError,
                            onRetry: () => unawaited(_loadSupportSession()),
                            compact: true,
                          ),
                        ),
                        SupportChatComposer(
                          controller: _messageController,
                          enabled: _canReply && !_isSending && !_isLoading,
                          isSending: _isSending,
                          onSend: () => unawaited(_sendMessage()),
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: AppColors.loginButton,
                elevation: 6,
                shadowColor: Colors.black.withValues(alpha: 0.25),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => unawaited(_toggleOpen()),
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: fabSize,
                    height: fabSize,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isOpen
                            ? Icons.close_rounded
                            : Icons.chat_bubble_outline_rounded,
                        key: ValueKey(_isOpen),
                        color: Colors.white,
                        size: r.iconMd,
                      ),
                    ),
                  ),
                ),
              ),
              if (!_isOpen && _unreadCount > 0)
                Positioned(
                  top: -r.gap(2),
                  right: -r.gap(2),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _unreadCount > 9 ? r.gap(5) : r.gap(4),
                      vertical: r.gap(2),
                    ),
                    constraints: BoxConstraints(
                      minWidth: r.w(18).clamp(16.0, 20.0),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(r.gap(10)),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(10).clamp(9.0, 11.0),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
