import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../config/app_strings.dart';
import '../../config/dashboard_theme.dart';
import '../../shared/widgets/app_strings_scope.dart';
import 'support_chat_loader.dart';

class SupportChatTimeFormatter {
  SupportChatTimeFormatter._();

  static String format(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $period';
  }
}

class SupportChatListEntry {
  const SupportChatListEntry.message(
    this.message, {
    this.showAvatar = true,
  })  : dayLabel = null,
        isDayLabel = false;

  const SupportChatListEntry.dayLabel(this.dayLabel)
      : message = null,
        showAvatar = false,
        isDayLabel = true;

  final SupportChatMessage? message;
  final String? dayLabel;
  final bool showAvatar;
  final bool isDayLabel;
}

class SupportChatThreadBuilder {
  SupportChatThreadBuilder._();

  static String dayLabel(DateTime day, AppStrings strings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(day.year, day.month, day.day);

    if (messageDay == today) return strings.chatHistoryToday;
    if (messageDay == yesterday) return strings.chatHistoryYesterday;
    return strings
        .formatSupportTicketDateTime(
          DateTime(day.year, day.month, day.day, 12),
        )
        .split(' • ')
        .first;
  }

  static List<SupportChatListEntry> buildEntries(
    List<SupportChatMessage> messages,
    AppStrings strings,
  ) {
    final entries = <SupportChatListEntry>[];
    DateTime? currentDay;
    SupportChatMessage? previous;

    for (final message in messages) {
      final createdAt = message.createdAt;
      if (createdAt != null) {
        final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
        if (currentDay == null || day != currentDay) {
          currentDay = day;
          entries.add(SupportChatListEntry.dayLabel(dayLabel(day, strings)));
        }
      }

      final showAvatar = previous == null ||
          previous.isFromDriver != message.isFromDriver;
      entries.add(
        SupportChatListEntry.message(message, showAvatar: showAvatar),
      );
      previous = message;
    }

    return entries;
  }
}

class SupportChatMessageList extends StatelessWidget {
  const SupportChatMessageList({
    super.key,
    required this.scrollController,
    required this.messages,
    required this.isLoading,
    this.loadError,
    this.onRetry,
    this.padding,
    this.compact = false,
  });

  final ScrollController scrollController;
  final List<SupportChatMessage> messages;
  final bool isLoading;
  final String? loadError;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry? padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final contentPadding = padding ??
        EdgeInsets.fromLTRB(
          r.gap(compact ? 10 : 16),
          r.gap(compact ? 8 : 12),
          r.gap(compact ? 10 : 16),
          r.gap(compact ? 8 : 12),
        );

    if (isLoading && messages.isEmpty) {
      return SupportChatLazyLoader(
        compact: compact,
        padding: contentPadding,
      );
    }

    if (loadError != null && messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(r.gap(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(14).clamp(13.0, 15.0),
                  color: dashboard.bodyText,
                ),
              ),
              if (onRetry != null) ...[
                SizedBox(height: r.gap(12)),
                TextButton(onPressed: onRetry, child: Text(s.tryAgain)),
              ],
            ],
          ),
        ),
      );
    }

    if (messages.isEmpty) {
      return SupportChatEmptyState(compact: compact);
    }

    final entries = SupportChatThreadBuilder.buildEntries(messages, s);

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: contentPadding,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry.isDayLabel) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: r.gap(compact ? 8 : 12),
              top: r.gap(4),
            ),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.gap(10),
                  vertical: r.gap(5),
                ),
                decoration: BoxDecoration(
                  color: dashboard.inputFill.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(r.gap(12)),
                ),
                child: Text(
                  entry.dayLabel!,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(11).clamp(10.0, 12.0),
                    fontWeight: FontWeight.w600,
                    color: dashboard.secondaryText,
                  ),
                ),
              ),
            ),
          );
        }

        final message = entry.message!;
        return Padding(
          padding: EdgeInsets.only(bottom: r.gap(compact ? 6 : 10)),
          child: message.isFromDriver
              ? SupportChatDriverBubble(
                  message: message.message,
                  createdAt: message.createdAt,
                  isPending: message.id.startsWith('local-'),
                  compact: compact,
                  showAvatar: entry.showAvatar,
                )
              : SupportChatAdminBubble(
                  message: message.message,
                  createdAt: message.createdAt,
                  isUnread: message.isUnread,
                  compact: compact,
                  showAvatar: entry.showAvatar,
                ),
        );
      },
    );
  }
}

class SupportChatEmptyState extends StatelessWidget {
  const SupportChatEmptyState({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.gap(compact ? 16 : 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r.w(compact ? 48 : 56).clamp(44.0, 60.0),
              height: r.w(compact ? 48 : 56).clamp(44.0, 60.0),
              decoration: BoxDecoration(
                color: dashboard.inputFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.support_agent_rounded,
                color: AppColors.loginButton,
                size: r.iconMd,
              ),
            ),
            SizedBox(height: r.gap(12)),
            Text(
              s.supportChatWelcome,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(compact ? 14 : 16).clamp(13.0, 17.0),
                color: dashboard.secondaryText,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportChatHeader extends StatelessWidget {
  const SupportChatHeader({
    super.key,
    required this.onClose,
    this.onViewHistory,
    this.compact = false,
  });

  final VoidCallback onClose;
  final VoidCallback? onViewHistory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final avatarSize = r.w(compact ? 34 : 40).clamp(32.0, 44.0);

    return Container(
      padding: EdgeInsets.fromLTRB(
        r.gap(compact ? 10 : 12),
        r.gap(compact ? 10 : 12),
        r.gap(compact ? 6 : 8),
        r.gap(compact ? 10 : 12),
      ),
      decoration: BoxDecoration(
        color: dashboard.surface,
        border: Border(bottom: BorderSide(color: dashboard.divider)),
        borderRadius: compact
            ? BorderRadius.vertical(top: Radius.circular(r.borderRadiusLg))
            : null,
      ),
      child: Row(
        children: [
          if (!compact)
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: r.sp(18).clamp(16.0, 20.0),
                color: dashboard.primaryText,
              ),
            ),
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: AppColors.loginButton.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: AppColors.loginButton,
              size: r.iconSm,
            ),
          ),
          SizedBox(width: r.gap(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.supportChatAgentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(compact ? 14 : 16).clamp(14.0, 17.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                  ),
                ),
                SizedBox(height: r.gap(2)),
                Text(
                  s.supportChatAgentSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(compact ? 11 : 13).clamp(11.0, 14.0),
                    color: dashboard.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          if (onViewHistory != null)
            TextButton(
              onPressed: onViewHistory,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: r.gap(6)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                s.viewChatHistory,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(12).clamp(11.0, 13.0),
                  fontWeight: FontWeight.w600,
                  color: AppColors.loginButton,
                ),
              ),
            ),
          if (compact)
            IconButton(
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: dashboard.primaryText,
              ),
            ),
        ],
      ),
    );
  }
}

class SupportChatAdminBubble extends StatelessWidget {
  const SupportChatAdminBubble({
    required this.message,
    this.createdAt,
    this.isUnread = false,
    this.compact = false,
    this.showAvatar = true,
  });

  final String message;
  final DateTime? createdAt;
  final bool isUnread;
  final bool compact;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final avatarSize = r.w(compact ? 24 : 28).clamp(22.0, 32.0);
    final cleaned = SupportChatLoader.cleanAdminMessage(message);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: avatarSize,
          child: showAvatar
              ? Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    color: AppColors.loginButton.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    size: r.iconSm * 0.9,
                    color: AppColors.loginButton,
                  ),
                )
              : null,
        ),
        SizedBox(width: r.gap(8)),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAvatar)
                Padding(
                  padding: EdgeInsets.only(left: r.gap(2), bottom: r.gap(4)),
                  child: Text(
                    s.supportChatAgentName,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(11).clamp(10.0, 12.0),
                      fontWeight: FontWeight.w600,
                      color: AppColors.loginButton,
                    ),
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.gap(compact ? 12 : 14),
                  vertical: r.gap(compact ? 10 : 12),
                ),
                decoration: BoxDecoration(
                  color: dashboard.chatBubbleIncoming,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(r.gap(4)),
                    topRight: Radius.circular(r.gap(12)),
                    bottomLeft: Radius.circular(r.gap(12)),
                    bottomRight: Radius.circular(r.gap(12)),
                  ),
                  border: isUnread
                      ? Border.all(color: const Color(0xFF2563EB), width: 1.2)
                      : null,
                ),
                child: Text(
                  cleaned,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(compact ? 14 : 16).clamp(13.0, 17.0),
                    color: dashboard.bodyText,
                    height: 1.45,
                  ),
                ),
              ),
              if (createdAt != null) ...[
                SizedBox(height: r.gap(4)),
                Text(
                  SupportChatTimeFormatter.format(createdAt),
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(10).clamp(9.0, 11.0),
                    color: dashboard.mutedText,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!compact) const Spacer(),
      ],
    );
  }
}

class SupportChatDriverBubble extends StatelessWidget {
  const SupportChatDriverBubble({
    required this.message,
    this.createdAt,
    this.isPending = false,
    this.compact = false,
    this.showAvatar = true,
  });

  final String message;
  final DateTime? createdAt;
  final bool isPending;
  final bool compact;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final avatarSize = r.w(compact ? 24 : 28).clamp(22.0, 32.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Spacer(),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.gap(compact ? 12 : 14),
                  vertical: r.gap(compact ? 10 : 12),
                ),
                decoration: BoxDecoration(
                  color: AppColors.loginButton,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(r.gap(12)),
                    topRight: Radius.circular(r.gap(4)),
                    bottomLeft: Radius.circular(r.gap(12)),
                    bottomRight: Radius.circular(r.gap(12)),
                  ),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(compact ? 14 : 16).clamp(13.0, 17.0),
                    color: Colors.white,
                    height: 1.45,
                  ),
                ),
              ),
              if (createdAt != null) ...[
                SizedBox(height: r.gap(4)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      SupportChatTimeFormatter.format(createdAt),
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(10).clamp(9.0, 11.0),
                        color: dashboard.mutedText,
                      ),
                    ),
                    SizedBox(width: r.gap(4)),
                    Icon(
                      isPending ? Icons.done_rounded : Icons.done_all_rounded,
                      size: r.sp(13).clamp(12.0, 14.0),
                      color: isPending
                          ? dashboard.mutedText
                          : const Color(0xFF1F6FEA),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (showAvatar) ...[
          SizedBox(width: r.gap(8)),
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: const BoxDecoration(
              color: AppColors.loginButton,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(r.gap(4)),
              child: Image.asset(
                AppConstants.userCircleIconAsset,
                fit: BoxFit.contain,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
        ] else
          SizedBox(width: avatarSize + r.gap(8)),
      ],
    );
  }
}

class SupportChatComposer extends StatelessWidget {
  const SupportChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.onSend,
    this.compact = false,
    this.horizontalPadding,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final VoidCallback onSend;
  final bool compact;
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final sendSize = r.w(compact ? 40 : 44).clamp(36.0, 48.0);
    final sidePadding =
        horizontalPadding ?? r.gap(compact ? 10 : (r.isTablet ? 32 : 16));

    return Container(
      decoration: BoxDecoration(
        color: dashboard.surface,
        border: Border(top: BorderSide(color: dashboard.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        sidePadding,
        r.gap(8),
        sidePadding,
        r.gap(compact ? 10 : 12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.gap(14)),
              decoration: BoxDecoration(
                color: dashboard.inputFill,
                borderRadius: BorderRadius.circular(r.gap(24)),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
                scrollPadding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom + r.gap(80),
                ),
                decoration: InputDecoration(
                  hintText: enabled ? s.typeMessage : s.repliesAreClosed,
                  hintStyle: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(compact ? 14 : 16).clamp(13.0, 17.0),
                    color: dashboard.mutedText,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: r.h(compact ? 11 : 14),
                  ),
                ),
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(compact ? 14 : 16).clamp(13.0, 17.0),
                  color: dashboard.bodyText,
                ),
              ),
            ),
          ),
          SizedBox(width: r.gap(8)),
          Material(
            color: enabled
                ? AppColors.loginButton
                : AppColors.loginButton.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: enabled && !isSending ? onSend : null,
              customBorder: const CircleBorder(),
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
                      : Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: r.iconSm,
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

class SupportChatLazyLoader extends StatefulWidget {
  const SupportChatLazyLoader({
    super.key,
    this.compact = false,
    this.padding,
  });

  final bool compact;
  final EdgeInsetsGeometry? padding;

  @override
  State<SupportChatLazyLoader> createState() => _SupportChatLazyLoaderState();
}

class _SupportChatLazyLoaderState extends State<SupportChatLazyLoader>
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
    final avatarSize = r.w(widget.compact ? 24 : 28).clamp(22.0, 32.0);
    final contentPadding = widget.padding ??
        EdgeInsets.fromLTRB(
          r.gap(widget.compact ? 10 : 16),
          r.gap(widget.compact ? 8 : 12),
          r.gap(widget.compact ? 10 : 16),
          r.gap(widget.compact ? 8 : 12),
        );

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: contentPadding,
          children: [
            _SupportLazyAdminRow(
              opacity: opacity,
              dashboard: dashboard,
              avatarSize: avatarSize,
              bubbleWidth: r.w(widget.compact ? 150 : 190).clamp(130.0, 220.0),
              bubbleHeight: r.h(widget.compact ? 44 : 52).clamp(38.0, 60.0),
              compact: widget.compact,
              r: r,
            ),
            SizedBox(height: r.gap(widget.compact ? 8 : 12)),
            _SupportLazyDriverRow(
              opacity: opacity,
              bubbleWidth: r.w(widget.compact ? 120 : 150).clamp(100.0, 180.0),
              bubbleHeight: r.h(widget.compact ? 36 : 44).clamp(32.0, 52.0),
              compact: widget.compact,
              r: r,
            ),
            SizedBox(height: r.gap(widget.compact ? 8 : 12)),
            _SupportLazyAdminRow(
              opacity: opacity,
              dashboard: dashboard,
              avatarSize: avatarSize,
              bubbleWidth: r.w(widget.compact ? 130 : 170).clamp(110.0, 200.0),
              bubbleHeight: r.h(widget.compact ? 36 : 44).clamp(32.0, 52.0),
              compact: widget.compact,
              r: r,
              showAvatar: false,
            ),
            SizedBox(height: r.gap(widget.compact ? 8 : 12)),
            _SupportLazyDriverRow(
              opacity: opacity,
              bubbleWidth: r.w(widget.compact ? 145 : 180).clamp(120.0, 210.0),
              bubbleHeight: r.h(widget.compact ? 44 : 52).clamp(38.0, 60.0),
              compact: widget.compact,
              r: r,
            ),
          ],
        );
      },
    );
  }
}

class _SupportLazyAdminRow extends StatelessWidget {
  const _SupportLazyAdminRow({
    required this.opacity,
    required this.dashboard,
    required this.avatarSize,
    required this.bubbleWidth,
    required this.bubbleHeight,
    required this.compact,
    required this.r,
    this.showAvatar = true,
  });

  final double opacity;
  final DashboardTheme dashboard;
  final double avatarSize;
  final double bubbleWidth;
  final double bubbleHeight;
  final bool compact;
  final AppResponsive r;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: avatarSize,
          child: showAvatar
              ? _SupportLazyBlock(
                  opacity: opacity,
                  color: AppColors.loginButton.withValues(alpha: 0.25),
                  height: avatarSize,
                  width: avatarSize,
                  borderRadius: avatarSize,
                )
              : null,
        ),
        SizedBox(width: r.gap(8)),
        _SupportLazyBlock(
          opacity: opacity,
          color: dashboard.chatBubbleIncoming,
          height: bubbleHeight,
          width: bubbleWidth,
          borderRadius: r.gap(12),
        ),
        if (!compact) const Spacer(),
      ],
    );
  }
}

class _SupportLazyDriverRow extends StatelessWidget {
  const _SupportLazyDriverRow({
    required this.opacity,
    required this.bubbleWidth,
    required this.bubbleHeight,
    required this.compact,
    required this.r,
  });

  final double opacity;
  final double bubbleWidth;
  final double bubbleHeight;
  final bool compact;
  final AppResponsive r;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!compact) const Spacer(),
        _SupportLazyBlock(
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

class _SupportLazyBlock extends StatelessWidget {
  const _SupportLazyBlock({
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
