import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/dashboard_theme.dart';
import '../../config/app_constants.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../services/auth_service.dart';
import '../support/support_chat_widgets.dart';
import 'models/support_ticket.dart';

class SupportTicketDetailArgs {
  const SupportTicketDetailArgs({
    required this.ticketId,
    required this.subject,
    this.displayId,
  });

  final String ticketId;
  final String subject;
  final String? displayId;

  String get headerId => displayId?.trim().isNotEmpty == true
      ? displayId!.trim()
      : ticketId;
}

class SupportTicketDetailView extends StatefulWidget {
  const SupportTicketDetailView({
    required this.ticket,
    super.key,
  });

  final SupportTicketDetailArgs ticket;

  @override
  State<SupportTicketDetailView> createState() =>
      _SupportTicketDetailViewState();
}

class _SupportTicketDetailViewState extends State<SupportTicketDetailView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <SupportTicketMessage>[];

  var _isLoading = true;
  var _isSending = false;
  var _canReply = true;
  String? _loadError;
  late String _subject;
  late String _headerId;

  @override
  void initState() {
    super.initState();
    _subject = widget.ticket.subject;
    _headerId = widget.ticket.headerId;
    unawaited(_loadConversation());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final response = await AuthService.getSupportTicketConversation(
      ticketId: widget.ticket.ticketId,
    );

    if (!mounted) return;

    if (response['success'] != true) {
      setState(() {
        _isLoading = false;
        _loadError = AuthService.extractErrorMessage(
          response,
          fallback: 'Could not load conversation.',
        );
      });
      return;
    }

    final conversation = AuthService.extractSupportTicketConversation(response);
    if (conversation == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'Could not read conversation.';
      });
      return;
    }

    final ticket = conversation.ticket;
    setState(() {
      _isLoading = false;
      _loadError = null;
      _canReply = conversation.canReply;
      _messages
        ..clear()
        ..addAll(conversation.messages);
      if (ticket != null) {
        if (ticket.subject.trim().isNotEmpty) {
          _subject = ticket.subject.trim();
        }
        if (ticket.displayId != '--') {
          _headerId = ticket.displayId;
        }
      }
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || !_canReply) return;

    setState(() => _isSending = true);

    final optimisticId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = SupportTicketMessage(
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
      ticketId: widget.ticket.ticketId,
      message: text,
    );

    if (!mounted) return;

    if (response['success'] != true) {
      setState(() {
        _messages.removeWhere((message) => message.id == optimisticId);
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.extractErrorMessage(
              response,
              fallback: 'Could not send reply.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSending = false);
    await _loadConversation();
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

    return Scaffold(
      backgroundColor: dashboard.screenBackground,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: r.maxContentWidth),
            child: Column(
              children: [
                _TicketDetailHeader(
                  subject: _subject,
                  ticketId: _headerId,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.loginButton,
                    onRefresh: _loadConversation,
                    child: _buildMessageList(r, dashboard),
                  ),
                ),
                _TicketChatComposer(
                  controller: _messageController,
                  enabled: _canReply && !_isSending,
                  isSending: _isSending,
                  onSend: () => unawaited(_sendMessage()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(AppResponsive r, DashboardTheme dashboard) {
    if (_isLoading && _messages.isEmpty) {
      return const SupportChatLazyLoader();
    }

    if (_loadError != null && _messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(r.gap(24)),
        children: [
          SizedBox(height: r.gap(120)),
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 18.0),
              color: dashboard.bodyText,
            ),
          ),
          SizedBox(height: r.gap(16)),
          Center(
            child: TextButton(
              onPressed: () => unawaited(_loadConversation()),
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (_messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(r.gap(24)),
        children: [
          SizedBox(height: r.gap(120)),
          Text(
            'No messages yet. Send a reply to start the conversation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 18.0),
              color: dashboard.mutedText,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        r.gap(16),
        r.gap(20),
        r.gap(16),
        r.gap(12),
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return Padding(
          padding: EdgeInsets.only(bottom: r.gap(12)),
          child: message.isFromDriver
              ? _DriverMessageBubble(
                  message: message.message,
                  isPending: message.id.startsWith('local-'),
                )
              : _SupportMessageBubble(message: message.message),
        );
      },
    );
  }
}

class _TicketDetailHeader extends StatelessWidget {
  const _TicketDetailHeader({
    required this.subject,
    required this.ticketId,
  });

  final String subject;
  final String ticketId;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.gap(8),
        r.gap(8),
        r.gap(16),
        r.gap(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: r.sp(18).clamp(16.0, 20.0),
              color: dashboard.primaryText,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: r.gap(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(18).clamp(17.0, 20.0),
                      fontWeight: FontWeight.w700,
                      color: dashboard.primaryText,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: r.gap(4)),
                  Text(
                    ticketId,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(14).clamp(13.0, 16.0),
                      color: dashboard.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportMessageBubble extends StatelessWidget {
  const _SupportMessageBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final avatarSize = r.w(28).clamp(24.0, 32.0);
    final chatWidth = r.maxContentWidth - (r.gap(16) * 2);
    final bubbleWidth = chatWidth - avatarSize - r.gap(8);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            color: dashboard.iconBox,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.support_agent_rounded,
            size: r.iconSm,
            color: AppColors.loginButton,
          ),
        ),
        SizedBox(width: r.gap(8)),
        SizedBox(
          width: bubbleWidth * 0.82,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.gap(14),
              vertical: r.gap(12),
            ),
            decoration: BoxDecoration(
              color: dashboard.inputFill,
              borderRadius: BorderRadius.circular(r.gap(12)),
            ),
            child: Text(
              message,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(16).clamp(15.0, 18.0),
                color: dashboard.bodyText,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverMessageBubble extends StatelessWidget {
  const _DriverMessageBubble({
    required this.message,
    this.isPending = false,
  });

  final String message;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final avatarSize = r.w(28).clamp(24.0, 32.0);
    final chatWidth = r.maxContentWidth - (r.gap(16) * 2);
    final bubbleWidth = chatWidth - avatarSize - r.gap(8);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Spacer(),
        SizedBox(
          width: bubbleWidth * 0.82,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.gap(14),
              vertical: r.gap(12),
            ),
            decoration: BoxDecoration(
              color: dashboard.iconBox,
              borderRadius: BorderRadius.circular(r.gap(12)),
            ),
            child: Text(
              message,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(16).clamp(15.0, 18.0),
                color: dashboard.bodyText.withValues(alpha: isPending ? 0.7 : 1),
                height: 1.45,
              ),
            ),
          ),
        ),
        SizedBox(width: r.gap(8)),
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: const BoxDecoration(
            color: AppColors.loginButton,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(r.gap(5)),
            child: Image.asset(
              AppConstants.userCircleIconAsset,
              fit: BoxFit.contain,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketChatComposer extends StatelessWidget {
  const _TicketChatComposer({
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final sendSize = r.w(44).clamp(40.0, 48.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.gap(16),
        r.gap(8),
        r.gap(16),
        r.gap(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.gap(14)),
              decoration: BoxDecoration(
                color: dashboard.inputFill,
                borderRadius: BorderRadius.circular(r.gap(10)),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
                decoration: InputDecoration(
                  hintText: enabled ? 'Enter Text' : 'Replies are closed',
                  hintStyle: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(16).clamp(15.0, 18.0),
                    color: dashboard.mutedText,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: r.h(14),
                  ),
                ),
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(16).clamp(15.0, 18.0),
                  color: dashboard.bodyText,
                ),
              ),
            ),
          ),
          SizedBox(width: r.gap(10)),
          Material(
            color: enabled ? AppColors.loginButton : dashboard.mutedText,
            borderRadius: BorderRadius.circular(r.gap(10)),
            child: InkWell(
              onTap: enabled && !isSending ? onSend : null,
              borderRadius: BorderRadius.circular(r.gap(10)),
              child: SizedBox(
                width: sendSize,
                height: sendSize,
                child: Center(
                  child: isSending
                      ? SizedBox(
                          width: r.iconSm,
                          height: r.iconSm,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Image.asset(
                          AppConstants.chatSendIconAsset,
                          width: r.iconSm,
                          height: r.iconSm,
                          fit: BoxFit.contain,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
