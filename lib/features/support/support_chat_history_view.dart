import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_responsive.dart';
import '../../config/app_strings.dart';
import '../../config/dashboard_theme.dart';
import '../../services/auth_service.dart';
import '../profile/models/support_ticket.dart';
import 'support_chat_loader.dart';
import 'support_chat_widgets.dart';

class SupportChatHistoryView extends StatefulWidget {
  const SupportChatHistoryView({super.key});

  @override
  State<SupportChatHistoryView> createState() => _SupportChatHistoryViewState();
}

class _SupportChatHistoryViewState extends State<SupportChatHistoryView> {
  static const _pollInterval = Duration(seconds: 8);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <SupportChatMessage>[];

  Timer? _pollTimer;
  var _isLoading = true;
  var _isFetching = false;
  var _isSending = false;
  var _canReply = true;
  String? _loadError;
  String? _activeTicketId;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_loadHistory(markUnreadAsRead: false, silent: true));
    });
    unawaited(_loadHistory(markUnreadAsRead: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory({
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
      await _loadHistory(markUnreadAsRead: false);
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
    await _loadHistory(markUnreadAsRead: false);
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 16);

    return Scaffold(
      backgroundColor: dashboard.scaffold,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: r.maxContentWidth),
            child: Column(
              children: [
                SupportChatHeader(
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.loginButton,
                    onRefresh: () => _loadHistory(markUnreadAsRead: false),
                    child: SupportChatMessageList(
                      scrollController: _scrollController,
                      messages: _messages,
                      isLoading: _isLoading,
                      loadError: _loadError,
                      onRetry: () => unawaited(_loadHistory()),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        r.gap(8),
                        horizontalPadding,
                        r.gap(12),
                      ),
                    ),
                  ),
                ),
                SupportChatComposer(
                  controller: _messageController,
                  enabled: _canReply && !_isSending && !_isLoading,
                  isSending: _isSending,
                  onSend: () => unawaited(_sendMessage()),
                  horizontalPadding: horizontalPadding,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
