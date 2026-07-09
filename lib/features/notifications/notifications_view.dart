import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../config/app_strings.dart';
import '../../config/dashboard_theme.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_strings_scope.dart';
import 'models/driver_notification.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final List<DriverNotification> _notifications = [];
  var _isLoading = true;
  var _isMarkingAllRead = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNotifications());
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await AuthService.getDriverNotifications();
    if (!mounted) return;

    if (response['success'] != true) {
      setState(() {
        _isLoading = false;
        _errorMessage = AuthService.extractErrorMessage(
          response,
          fallback: AppStringsScope.of(context).errLoadNotifications,
        );
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _notifications
        ..clear()
        ..addAll(AuthService.extractDriverNotifications(response));
    });
  }

  Future<void> _markAllAsRead() async {
    final unreadIds = _notifications
        .where((notification) => !notification.isRead)
        .map((notification) => notification.id)
        .toList();

    if (unreadIds.isEmpty || _isMarkingAllRead) return;

    setState(() => _isMarkingAllRead = true);

    final response = await AuthService.markNotificationsAsRead(
      notificationIds: unreadIds,
    );

    if (!mounted) return;

    if (response['success'] != true) {
      setState(() => _isMarkingAllRead = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.extractErrorMessage(
              response,
              fallback: AppStringsScope.of(context).errMarkNotificationsRead,
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isMarkingAllRead = false;
      for (var i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
        }
      }
    });
  }

  Future<void> _markNotificationAsRead(DriverNotification notification) async {
    if (notification.isRead) return;

    final response = await AuthService.markNotificationsAsRead(
      notificationIds: [notification.id],
    );
    if (!mounted || response['success'] != true) return;

    final index = _notifications.indexWhere((item) => item.id == notification.id);
    if (index == -1) return;

    setState(() {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    });
  }

  bool get _hasUnreadNotifications =>
      _notifications.any((notification) => !notification.isRead);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);

    return Scaffold(
      backgroundColor: dashboard.scaffold,
      appBar: AppBar(
        backgroundColor: dashboard.scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: dashboard.primaryText,
            size: r.sp(18).clamp(16.0, 20.0),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  r.gap(12),
                ),
                child: Text(
                  s.notifications,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(27).clamp(24.0, 30.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                    height: 1.15,
                  ),
                ),
              ),
              if (!_isLoading && _notifications.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    r.gap(20),
                  ),
                  child: InkWell(
                    onTap: _hasUnreadNotifications && !_isMarkingAllRead
                        ? () => unawaited(_markAllAsRead())
                        : null,
                    borderRadius: BorderRadius.circular(r.gap(6)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: r.gap(4)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isMarkingAllRead)
                            SizedBox(
                              width: r.sp(18).clamp(16.0, 20.0),
                              height: r.sp(18).clamp(16.0, 20.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: dashboard.mutedText,
                              ),
                            )
                          else
                            Icon(
                              Icons.done_all_rounded,
                              size: r.sp(18).clamp(16.0, 20.0),
                              color: _hasUnreadNotifications
                                  ? dashboard.mutedText
                                  : dashboard.mutedText.withValues(alpha: 0.45),
                            ),
                          SizedBox(width: r.gap(8)),
                          Text(
                            s.markAllRead,
                            style: TextStyle(
                              fontFamily: AppFonts.satoshi,
                              fontSize: r.sp(15).clamp(14.0, 17.0),
                              fontWeight: FontWeight.w500,
                              color: _hasUnreadNotifications
                                  ? dashboard.mutedText
                                  : dashboard.mutedText.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _buildBody(r, dashboard, horizontalPadding, s),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    AppResponsive r,
    DashboardTheme dashboard,
    double horizontalPadding,
    AppStrings s,
  ) {
    if (_isLoading) {
      return _LazyNotificationsList(horizontalPadding: horizontalPadding);
    }

    if (_errorMessage != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(16).clamp(15.0, 18.0),
                color: dashboard.bodyText,
              ),
            ),
            SizedBox(height: r.gap(16)),
            TextButton(
              onPressed: () => unawaited(_loadNotifications()),
              child: Text(s.retry),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Text(
            s.noNotifications,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 18.0),
              color: dashboard.mutedText,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.loginButton,
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          r.gap(24),
        ),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) => SizedBox(height: r.gap(12)),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _NotificationCard(
            r: r,
            notification: notification,
            onTap: () => unawaited(_markNotificationAsRead(notification)),
          );
        },
      ),
    );
  }
}

class _LazyNotificationsList extends StatefulWidget {
  const _LazyNotificationsList({required this.horizontalPadding});

  final double horizontalPadding;

  @override
  State<_LazyNotificationsList> createState() => _LazyNotificationsListState();
}

class _LazyNotificationsListState extends State<_LazyNotificationsList>
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
    final iconSize = r.w(28).clamp(24.0, 32.0);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            widget.horizontalPadding,
            0,
            widget.horizontalPadding,
            r.gap(24),
          ),
          itemCount: 5,
          separatorBuilder: (_, _) => SizedBox(height: r.gap(12)),
          itemBuilder: (context, index) {
            return Container(
              padding: EdgeInsets.all(r.gap(14)),
              decoration: BoxDecoration(
                color: dashboard.inputFill,
                borderRadius: BorderRadius.circular(r.gap(12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LazyBlock(
                    opacity: opacity,
                    color: dashboard.secondaryText,
                    height: iconSize,
                    width: iconSize,
                    borderRadius: r.gap(8),
                  ),
                  SizedBox(width: r.gap(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LazyBlock(
                          opacity: opacity,
                          color: dashboard.primaryText,
                          height: r.sp(16).clamp(15.0, 18.0),
                          width: r.w(180).clamp(140.0, 220.0),
                        ),
                        SizedBox(height: r.gap(8)),
                        _LazyBlock(
                          opacity: opacity,
                          color: dashboard.bodyText,
                          height: r.sp(14).clamp(13.0, 16.0),
                          width: double.infinity,
                        ),
                        SizedBox(height: r.gap(6)),
                        _LazyBlock(
                          opacity: opacity,
                          color: dashboard.bodyText,
                          height: r.sp(14).clamp(13.0, 16.0),
                          width: r.w(220).clamp(180.0, 260.0),
                        ),
                        SizedBox(height: r.gap(10)),
                        _LazyBlock(
                          opacity: opacity,
                          color: AppColors.loginButton,
                          height: r.sp(13).clamp(12.0, 14.0),
                          width: r.w(72).clamp(60.0, 88.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.r,
    required this.notification,
    required this.onTap,
  });

  final AppResponsive r;
  final DriverNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    final iconSize = r.w(28).clamp(24.0, 32.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.gap(12)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.gap(14)),
          decoration: BoxDecoration(
            color: dashboard.inputFill,
            borderRadius: BorderRadius.circular(r.gap(12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    AppColors.loginButton,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    AppConstants.driverTabIconAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(width: r.gap(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.displayTitle,
                            style: TextStyle(
                              fontFamily: AppFonts.satoshi,
                              fontSize: r.sp(16).clamp(15.0, 18.0),
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              color: dashboard.primaryText,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          SizedBox(width: r.gap(8)),
                          Container(
                            width: r.w(8).clamp(7.0, 10.0),
                            height: r.w(8).clamp(7.0, 10.0),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: r.gap(6)),
                    Text(
                      notification.displayMessage,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(14).clamp(13.0, 16.0),
                        color: dashboard.bodyText,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: r.gap(8)),
                    Text(
                      notification.timeAgo,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(13).clamp(12.0, 14.0),
                        fontWeight: FontWeight.w600,
                        color: AppColors.loginButton,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
