import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../shared/widgets/profile_avatar_image.dart';
import '../../home/models/nearby_ride_offer.dart';
import '../call/in_app_call_args.dart';
import '../widgets/dial_modal.dart';
import '../../../shared/widgets/ride_panel_shared.dart';
import 'ride_chat_args.dart';

class RideChatView extends StatefulWidget {
  const RideChatView({super.key, required this.args});

  final RideChatArgs args;

  @override
  State<RideChatView> createState() => _RideChatViewState();
}

class _RideChatViewState extends State<RideChatView> {
  static const _pollInterval = Duration(seconds: 4);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];

  Timer? _pollTimer;
  var _isLoading = true;
  var _isFetching = false;
  var _isSending = false;
  var _canSendMessages = true;
  String? _loadError;
  String? _riderName;
  String? _riderPhotoUrl;
  String? _pickupAddress;
  String? _riderPhone;
  double? _riderRating;

  @override
  void initState() {
    super.initState();
    _riderName = widget.args.riderName;
    _riderPhotoUrl = widget.args.riderPhotoUrl;
    _pickupAddress = widget.args.pickupAddress;
    _riderRating = widget.args.riderRating;
    unawaited(_bootstrap());
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_refreshChat()));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadRideContext();
    await _refreshChat();
  }

  Future<void> _loadRideContext() async {
    final response = await AuthService.getDriverRideStatus(
      rideId: widget.args.rideId,
    );
    if (!mounted || response['success'] != true) return;

    final ride = AuthService.extractDriverRideStatus(response);
    final offer = ride == null ? null : NearbyRideOffer.fromMap(ride);
    if (offer == null || !mounted) return;

    setState(() {
      _riderName = offer.riderName ?? _riderName;
      _riderPhotoUrl = offer.riderPhotoUrl ?? _riderPhotoUrl;
      _pickupAddress = offer.pickupAddress != '--'
          ? offer.pickupAddress
          : _pickupAddress;
      _riderRating = offer.riderRating ?? _riderRating;
      _riderPhone = offer.riderPhone ?? _riderPhone;
    });
  }

  void _callRider() {
    unawaited(
      DialModal.show(
        context,
        riderName: _riderName ?? widget.args.riderName,
        initialPhoneNumber: _riderPhone,
        resolvePhoneNumber: _resolveRiderPhoneForDial,
        resolveOnDialPressed: _resolveRiderPhoneOnDial,
        onCallInApp: () {
          Navigator.of(context).pushNamed(
            AppRoutes.inAppCall,
            arguments: InAppCallArgs(
              rideId: widget.args.rideId,
              counterpartName: _riderName ?? widget.args.riderName ?? 'Rider',
              riderPhotoUrl: _riderPhotoUrl ?? widget.args.riderPhotoUrl,
              riderRating: _riderRating ?? widget.args.riderRating,
            ),
          );
        },
      ),
    );
  }

  Future<String?> _resolveRiderPhoneForDial() async {
    final result = await _resolveRiderPhoneOnDial();
    return result.phone;
  }

  Future<({Map<String, dynamic> response, String? phone})>
      _resolveRiderPhoneOnDial() async {
    final response = await AuthService.getDriverRideStatus(
      rideId: widget.args.rideId,
    );
    final ride = AuthService.extractDriverRideStatus(response);
    final offer = ride == null ? null : NearbyRideOffer.fromMap(ride);

    if (offer != null && mounted) {
      setState(() => _riderPhone = offer.riderPhone ?? _riderPhone);
    }

    return (
      response: response,
      phone: offer?.riderPhone ?? _riderPhone,
    );
  }

  Future<void> _refreshChat() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final response = await AuthService.getChatHistory(
        rideId: widget.args.rideId,
      );

      if (!mounted) return;

      if (response['success'] != true) {
        setState(() {
          _isLoading = false;
          _loadError = AuthService.extractErrorMessage(
            response,
            fallback: 'Could not load chat messages.',
          );
        });
        return;
      }

      final incoming = AuthService.extractChatMessages(response);
      final canSend = AuthService.extractCanSendMessages(response);
      final parsed = incoming
          .map(_ChatMessage.fromMap)
          .whereType<_ChatMessage>()
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final localPending = _messages
          .where((message) => message.id.startsWith('local-'))
          .toList();

      setState(() {
        _messages
          ..clear()
          ..addAll(parsed)
          ..addAll(
            localPending.where(
              (pending) => !parsed.any(
                (message) =>
                    message.isFromDriver &&
                    message.text == pending.text &&
                    message.createdAt
                            .difference(pending.createdAt)
                            .inSeconds
                            .abs() <
                        30,
              ),
            ),
          );
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _isLoading = false;
        _loadError = null;
        _canSendMessages = canSend;
      });

      _scrollToBottom();
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || !_canSendMessages) return;

    setState(() => _isSending = true);

    final optimisticId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = _ChatMessage(
      id: optimisticId,
      text: text,
      isFromDriver: true,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(optimistic);
    });
    _messageController.clear();
    _scrollToBottom();

    final response = await AuthService.sendChatMessage(
      rideId: widget.args.rideId,
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
              fallback: 'Could not send message.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSending = false);
    await _refreshChat();
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
      backgroundColor: dashboard.scaffold,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: r.maxContentWidth),
            child: Column(
              children: [
                _ChatHeader(
                  riderName: _riderName,
                  riderPhotoUrl: _riderPhotoUrl,
                  riderRating: _riderRating,
                  pickupAddress: _pickupAddress,
                  onCall: _callRider,
                ),
                Divider(height: 1, color: dashboard.divider),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshChat,
                    child: _buildMessageList(r, dashboard),
                  ),
                ),
                _ChatComposer(
                  controller: _messageController,
                  enabled: _canSendMessages && !_isSending,
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
      return const _LazyChatMessages();
    }

    if (_loadError != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(r.gap(24)),
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(14).clamp(13.0, 16.0),
              color: dashboard.secondaryText,
            ),
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(r.gap(24)),
          child: Text(
            'No messages yet. Say hello to your rider.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(14).clamp(13.0, 16.0),
              color: dashboard.secondaryText,
            ),
          ),
        ),
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
                  message: message.text,
                  createdAt: message.createdAt,
                  isPending: message.id.startsWith('local-'),
                )
              : _RiderMessageBubble(
                  message: message.text,
                  riderPhotoUrl: _riderPhotoUrl,
                  riderName: _riderName,
                ),
        );
      },
    );
  }
}

class _LazyChatMessages extends StatefulWidget {
  const _LazyChatMessages();

  @override
  State<_LazyChatMessages> createState() => _LazyChatMessagesState();
}

class _LazyChatMessagesState extends State<_LazyChatMessages>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final avatarSize = r.w(28).clamp(24.0, 32.0);
    final chatWidth = r.maxContentWidth - (r.gap(16) * 2);
    final bubbleWidth = chatWidth * 0.62;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            r.gap(16),
            r.gap(20),
            r.gap(16),
            r.gap(12),
          ),
          children: [
            _LazyRiderBubbleRow(
              opacity: opacity,
              dashboard: dashboard,
              avatarSize: avatarSize,
              bubbleWidth: bubbleWidth,
              bubbleHeight: r.h(52).clamp(44.0, 60.0),
              r: r,
            ),
            SizedBox(height: r.gap(12)),
            _LazyDriverBubbleRow(
              opacity: opacity,
              dashboard: dashboard,
              bubbleWidth: bubbleWidth * 0.85,
              bubbleHeight: r.h(44).clamp(38.0, 52.0),
              r: r,
            ),
            SizedBox(height: r.gap(12)),
            _LazyRiderBubbleRow(
              opacity: opacity,
              dashboard: dashboard,
              avatarSize: avatarSize,
              bubbleWidth: bubbleWidth * 0.72,
              bubbleHeight: r.h(44).clamp(38.0, 52.0),
              r: r,
            ),
            SizedBox(height: r.gap(12)),
            _LazyDriverBubbleRow(
              opacity: opacity,
              dashboard: dashboard,
              bubbleWidth: bubbleWidth,
              bubbleHeight: r.h(52).clamp(44.0, 60.0),
              r: r,
            ),
          ],
        );
      },
    );
  }
}

class _LazyRiderBubbleRow extends StatelessWidget {
  const _LazyRiderBubbleRow({
    required this.opacity,
    required this.dashboard,
    required this.avatarSize,
    required this.bubbleWidth,
    required this.bubbleHeight,
    required this.r,
  });

  final double opacity;
  final DashboardTheme dashboard;
  final double avatarSize;
  final double bubbleWidth;
  final double bubbleHeight;
  final AppResponsive r;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _LazyBlock(
          opacity: opacity,
          color: dashboard.secondaryText,
          height: avatarSize,
          width: avatarSize,
          borderRadius: avatarSize,
        ),
        SizedBox(width: r.gap(8)),
        _LazyBlock(
          opacity: opacity,
          color: dashboard.chatBubbleIncoming,
          height: bubbleHeight,
          width: bubbleWidth,
          borderRadius: r.gap(12),
        ),
        const Spacer(),
      ],
    );
  }
}

class _LazyDriverBubbleRow extends StatelessWidget {
  const _LazyDriverBubbleRow({
    required this.opacity,
    required this.dashboard,
    required this.bubbleWidth,
    required this.bubbleHeight,
    required this.r,
  });

  final double opacity;
  final DashboardTheme dashboard;
  final double bubbleWidth;
  final double bubbleHeight;
  final AppResponsive r;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        _LazyBlock(
          opacity: opacity,
          color: AppColors.loginButton,
          height: bubbleHeight,
          width: bubbleWidth,
          borderRadius: r.gap(12),
        ),
      ],
    );
  }
}

class _LazyBlock extends StatelessWidget {
  const _LazyBlock({
    required this.opacity,
    required this.color,
    required this.height,
    required this.width,
    this.borderRadius = 6,
  });

  final double opacity;
  final Color color;
  final double height;
  final double width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.text,
    required this.isFromDriver,
    required this.createdAt,
  });

  final String id;
  final String text;
  final bool isFromDriver;
  final DateTime createdAt;

  static _ChatMessage? fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString();
    final text = map['message']?.toString().trim();
    if (id == null || id.isEmpty || text == null || text.isEmpty) {
      return null;
    }

    final createdAt = DateTime.tryParse(
          map['created_at']?.toString() ??
              map['sent_at']?.toString() ??
              '',
        ) ??
        DateTime.now();

    return _ChatMessage(
      id: id,
      text: text,
      isFromDriver: map['sender_type']?.toString().toLowerCase() == 'driver',
      createdAt: createdAt,
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.onCall,
    this.riderName,
    this.riderPhotoUrl,
    this.riderRating,
    this.pickupAddress,
  });

  final VoidCallback onCall;
  final String? riderName;
  final String? riderPhotoUrl;
  final double? riderRating;
  final String? pickupAddress;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final avatarSize = r.w(44).clamp(40.0, 50.0);
    final displayName = riderName?.trim().isNotEmpty == true
        ? riderName!.trim()
        : 'Rider';
    final location = pickupAddress?.trim().isNotEmpty == true
        ? pickupAddress!.trim()
        : '--';
    final rating = riderRating;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.gap(8),
        r.gap(8),
        r.gap(16),
        r.gap(12),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: r.sp(18).clamp(16.0, 20.0),
              color: dashboard.primaryText,
            ),
          ),
          SizedBox(
            width: avatarSize + r.gap(4),
            height: avatarSize + r.gap(10),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                SizedBox(
                  width: avatarSize + r.gap(4),
                  height: avatarSize + r.gap(4),
                  child: CustomPaint(
                    painter: ProfileArcPainter(
                      color: AppColors.loginButton,
                      strokeWidth: r.w(2.5).clamp(2.0, 3.0),
                    ),
                    child: Center(
                      child: ClipOval(
                        child: ProfileAvatarImage(
                          size: avatarSize,
                          avatarUrl: riderPhotoUrl,
                          displayName: displayName,
                        ),
                      ),
                    ),
                  ),
                ),
                if (rating != null)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.gap(6),
                        vertical: r.gap(2),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.loginButton,
                        borderRadius: BorderRadius.circular(r.gap(6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: r.sp(10).clamp(9.0, 11.0),
                            color: Colors.white,
                          ),
                          SizedBox(width: r.gap(2)),
                          Text(
                            rating == rating.roundToDouble()
                                ? '${rating.round()}'
                                : rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontFamily: AppFonts.satoshi,
                              fontSize: r.sp(10).clamp(9.0, 11.0),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: r.gap(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(17).clamp(16.0, 19.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                  ),
                ),
                SizedBox(height: r.gap(2)),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: r.sp(14).clamp(13.0, 16.0),
                      color: dashboard.secondaryText,
                    ),
                    SizedBox(width: r.gap(4)),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontFamily: AppFonts.satoshi,
                          fontSize: r.sp(14).clamp(13.0, 16.0),
                          color: dashboard.secondaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: dashboard.card,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onCall,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: r.w(40).clamp(36.0, 44.0),
                height: r.w(40).clamp(36.0, 44.0),
                child: Icon(
                  Icons.phone_rounded,
                  size: r.iconSm,
                  color: dashboard.isDark
                      ? AppColors.loginButton
                      : Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderMessageBubble extends StatelessWidget {
  const _RiderMessageBubble({
    required this.message,
    this.riderPhotoUrl,
    this.riderName,
  });

  final String message;
  final String? riderPhotoUrl;
  final String? riderName;

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
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.loginButton,
              width: r.w(1.5).clamp(1.0, 2.0),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ProfileAvatarImage(
            size: avatarSize,
            avatarUrl: riderPhotoUrl,
            displayName: riderName,
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
              color: dashboard.chatBubbleIncoming,
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
        const Spacer(),
      ],
    );
  }
}

class _DriverMessageBubble extends StatelessWidget {
  const _DriverMessageBubble({
    required this.message,
    required this.createdAt,
    this.isPending = false,
  });

  final String message;
  final DateTime createdAt;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final chatWidth = r.maxContentWidth - (r.gap(16) * 2);

    return Row(
      children: [
        const Spacer(),
        SizedBox(
          width: chatWidth * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: r.gap(14),
                  vertical: r.gap(12),
                ),
                decoration: BoxDecoration(
                  color: AppColors.loginButton,
                  borderRadius: BorderRadius.circular(r.gap(12)),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(16).clamp(15.0, 18.0),
                    color: Colors.white,
                    height: 1.45,
                  ),
                ),
              ),
              SizedBox(height: r.gap(4)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatChatTime(createdAt),
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(11).clamp(10.0, 12.0),
                      color: dashboard.secondaryText,
                    ),
                  ),
                  SizedBox(width: r.gap(4)),
                  Icon(
                    isPending ? Icons.done_rounded : Icons.done_all_rounded,
                    size: r.sp(14).clamp(13.0, 15.0),
                    color: isPending
                        ? dashboard.mutedText
                        : const Color(0xFF1F6FEA),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatChatTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:$minute $period';
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.isSending = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final bool isSending;

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
                  hintText: enabled ? 'Type a message' : 'Messaging unavailable',
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
            color: enabled
                ? AppColors.loginButton
                : AppColors.loginButton.withValues(alpha: 0.45),
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
                          width: r.sp(20).clamp(18.0, 22.0),
                          height: r.sp(20).clamp(18.0, 22.0),
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
