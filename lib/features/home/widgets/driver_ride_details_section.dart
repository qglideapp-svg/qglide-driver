import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../services/auth_service.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../models/driver_ride_details.dart';

class DriverRideDetailsSection extends StatefulWidget {
  const DriverRideDetailsSection({
    required this.rideId,
    this.initialDetails,
    this.showTitle = true,
    this.forceCompleted = false,
    super.key,
  });

  final String rideId;
  final DriverRideDetails? initialDetails;
  final bool showTitle;
  final bool forceCompleted;

  @override
  State<DriverRideDetailsSection> createState() =>
      _DriverRideDetailsSectionState();
}

class _DriverRideDetailsSectionState extends State<DriverRideDetailsSection> {
  DriverRideDetails? _details;
  var _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final cached = widget.initialDetails;
    if (cached != null && cached.id.isNotEmpty) {
      _details = cached;
      _isLoading = false;
    }
    unawaited(_loadDetails(showLoading: cached == null || cached.id.isEmpty));
  }

  Future<void> _loadDetails({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final result = await AuthService.fetchDriverRideDetails(
      rideId: widget.rideId,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.details != null) {
        final base = _details ?? widget.initialDetails;
        _details = base?.mergeWithFetched(
              result.details!,
              forceCompleted: widget.forceCompleted,
            ) ??
            result.details!;
      }
      _errorMessage = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const DriverRideDetailsSkeleton();
    }

    if (_errorMessage != null && _details == null) {
      return DriverRideDetailsErrorState(
        message: _errorMessage!,
        onRetry: () => unawaited(_loadDetails()),
      );
    }

    if (_details == null) {
      return const DriverRideDetailsSkeleton();
    }

    return DriverRideDetailsContent(
      details: _details!,
      showTitle: widget.showTitle,
    );
  }
}

class DriverRideDetailsContent extends StatelessWidget {
  const DriverRideDetailsContent({
    required this.details,
    this.showTitle = true,
    super.key,
  });

  final DriverRideDetails details;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text(
            'Details',
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(27).clamp(24.0, 30.0),
              fontWeight: FontWeight.w700,
              color: dashboard.primaryText,
              height: 1.15,
            ),
          ),
          ResponsiveGap(20),
        ],
        RideDetailsCard(
          title: 'Ride Details',
          children: [
            RideDetailsStatusRow(
              label: 'Status',
              status: details.statusDisplay,
              isCompleted: details.isCompleted,
            ),
            RideDetailsRow(
              label: 'Trip ID',
              value: details.tripIdDisplay,
            ),
            RideDetailsRow(
              label: 'Date',
              value: details.dateDisplay,
            ),
            RideDetailsRow(
              label: 'Total Amount',
              value: details.amountDisplay,
            ),
          ],
        ),
        ResponsiveGap(14),
        RideDetailsCard(
          title: 'Trip Details',
          children: [
            RideDetailsRow(
              label: 'Pickup:',
              value: details.pickupAddress,
              multilineValue: true,
            ),
            RideDetailsRow(
              label: 'Drop off',
              value: details.dropoffAddress,
              multilineValue: true,
            ),
            RideDetailsRow(
              label: 'Distance',
              value: details.distanceDisplay,
            ),
            RideDetailsRow(
              label: 'Duration',
              value: details.durationDisplay,
            ),
          ],
        ),
        ResponsiveGap(14),
        RideDetailsCard(
          title: 'Qglider Details',
          children: [
            RideDetailsRow(
              label: 'Name',
              value: details.riderNameDisplay,
            ),
            RideDetailsRow(
              label: 'email',
              value: details.riderEmailDisplay,
            ),
            RideDetailsRatingRow(
              label: 'Ratings',
              rating: details.riderRatingDisplay,
            ),
          ],
        ),
      ],
    );
  }
}

class RideDetailsCard extends StatelessWidget {
  const RideDetailsCard({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final cardColor = dashboard.isDark
        ? const Color(0xFF242118)
        : dashboard.card;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 18.0),
              fontWeight: FontWeight.w700,
              color: dashboard.primaryText,
            ),
          ),
          ResponsiveGap(14),
          ...children,
        ],
      ),
    );
  }
}

class RideDetailsRow extends StatelessWidget {
  const RideDetailsRow({
    required this.label,
    required this.value,
    this.multilineValue = false,
    super.key,
  });

  final String label;
  final String value;
  final bool multilineValue;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final displayValue = value.trim().isEmpty ? '--' : value.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: r.gap(12)),
      child: Row(
        crossAxisAlignment: multilineValue
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(14).clamp(13.0, 15.0),
                color: dashboard.secondaryText,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              displayValue,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(14).clamp(13.0, 15.0),
                fontWeight: FontWeight.w500,
                color: dashboard.primaryText,
                height: multilineValue ? 1.4 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RideDetailsStatusRow extends StatelessWidget {
  const RideDetailsStatusRow({
    required this.label,
    required this.status,
    required this.isCompleted,
    super.key,
  });

  final String label;
  final String status;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    const completedColor = Color(0xFF34C759);

    return Padding(
      padding: EdgeInsets.only(bottom: r.gap(12)),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(14).clamp(13.0, 15.0),
                color: dashboard.secondaryText,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCompleted) ...[
                    Icon(
                      Icons.check_circle,
                      size: r.iconSm,
                      color: completedColor,
                    ),
                    SizedBox(width: r.gap(6)),
                  ],
                  Text(
                    status,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(14).clamp(13.0, 15.0),
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? completedColor : dashboard.primaryText,
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

class RideDetailsRatingRow extends StatelessWidget {
  const RideDetailsRatingRow({
    required this.label,
    required this.rating,
    super.key,
  });

  final String label;
  final String rating;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(14).clamp(13.0, 15.0),
              color: dashboard.secondaryText,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: r.iconSm,
                  color: AppColors.loginButton,
                ),
                SizedBox(width: r.gap(4)),
                Text(
                  rating,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 15.0),
                    fontWeight: FontWeight.w600,
                    color: dashboard.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DriverRideDetailsErrorState extends StatelessWidget {
  const DriverRideDetailsErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.gap(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(15).clamp(14.0, 16.0),
                color: dashboard.bodyText,
              ),
            ),
            ResponsiveGap(16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Try again',
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  color: AppColors.loginButton,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverRideDetailsSkeleton extends StatefulWidget {
  const DriverRideDetailsSkeleton({super.key});

  @override
  State<DriverRideDetailsSkeleton> createState() =>
      _DriverRideDetailsSkeletonState();
}

class _DriverRideDetailsSkeletonState extends State<DriverRideDetailsSkeleton>
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
    final cardColor = dashboard.isDark
        ? const Color(0xFF242118)
        : dashboard.card;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LazyBlock(
              opacity: opacity,
              color: dashboard.primaryText,
              height: r.sp(27).clamp(24.0, 30.0),
              width: r.w(96).clamp(80.0, 120.0),
              borderRadius: r.gap(8),
            ),
            ResponsiveGap(20),
            ...List.generate(3, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: r.gap(14)),
                child: Container(
                  padding: EdgeInsets.all(r.gap(16)),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(r.borderRadiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LazyBlock(
                        opacity: opacity,
                        color: dashboard.primaryText,
                        height: r.sp(16).clamp(15.0, 18.0),
                        width: r.w(120).clamp(96.0, 140.0),
                        borderRadius: r.gap(6),
                      ),
                      ResponsiveGap(14),
                      ...List.generate(index == 1 ? 4 : 3, (rowIndex) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: r.gap(12)),
                          child: Row(
                            children: [
                              Expanded(
                                child: _LazyBlock(
                                  opacity: opacity,
                                  color: dashboard.secondaryText,
                                  height: r.sp(14).clamp(13.0, 15.0),
                                  width: r.w(72).clamp(60.0, 88.0),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _LazyBlock(
                                    opacity: opacity,
                                    color: dashboard.primaryText,
                                    height: r.sp(14).clamp(13.0, 15.0),
                                    width: r.w(120).clamp(96.0, 150.0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
          ],
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
    this.width,
    this.borderRadius = 6,
  });

  final double opacity;
  final Color color;
  final double height;
  final double? width;
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
