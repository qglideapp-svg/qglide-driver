import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../../../shared/widgets/ride_panel_shared.dart';
import '../models/nearby_ride_offer.dart';

class RiderAddedStopModal extends StatefulWidget {
  const RiderAddedStopModal({
    super.key,
    required this.notification,
    required this.countdownDuration,
  });

  final RiderStopNotification notification;
  final Duration countdownDuration;

  static Future<void> show(
    BuildContext context, {
    required RiderStopNotification notification,
    Duration countdownDuration = AppConstants.riderAddedStopNotificationDuration,
  } ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => RiderAddedStopModal(
        notification: notification,
        countdownDuration: countdownDuration,
      ),
    );
  }

  @override
  State<RiderAddedStopModal> createState() => _RiderAddedStopModalState();
}

class _RiderAddedStopModalState extends State<RiderAddedStopModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdownController;
  var _countdownCompleted = false;

  @override
  void initState() {
    super.initState();
    _countdownController = AnimationController(
      vsync: this,
      duration: widget.countdownDuration,
    )
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed ||
            _countdownCompleted ||
            !mounted) {
          return;
        }

        _countdownCompleted = true;
        Navigator.of(context).pop();
      })
      ..forward();
  }

  @override
  void dispose() {
    _countdownController.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final iconSize = r.w(72).clamp(64.0, 84.0);
    final arcStrokeWidth = r.w(6).clamp(5.0, 8.0);
    final arcSize = iconSize + arcStrokeWidth + r.gap(10);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: r.gap(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.gap(24)),
          decoration: BoxDecoration(
            color: dashboard.surface,
            borderRadius: BorderRadius.circular(r.borderRadiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: r.gap(24),
                offset: Offset(0, r.gap(8)),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _countdownController,
            builder: (context, child) {
              final remainingSeconds = (widget.countdownDuration.inSeconds -
                      widget.countdownDuration.inSeconds *
                          _countdownController.value)
                  .ceil()
                  .clamp(0, widget.countdownDuration.inSeconds);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: arcSize,
                    height: arcSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF4D6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_location_alt_outlined,
                            size: r.iconMd,
                            color: const Color(0xFFE3AA00),
                          ),
                        ),
                        SizedBox(
                          width: arcSize,
                          height: arcSize,
                          child: CustomPaint(
                            painter: ProfileArcPainter(
                              color: AppColors.loginButton,
                              strokeWidth: arcStrokeWidth,
                              progress: _countdownController.value,
                              countdown: true,
                              trackColor: AppColors.loginButton
                                  .withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                        Container(
                          width: iconSize * 0.42,
                          height: iconSize * 0.42,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$remainingSeconds',
                            style: TextStyle(
                              fontFamily: AppFonts.satoshi,
                              fontSize: r.sp(18).clamp(16.0, 22.0),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ResponsiveGap(r.isCompact ? 16 : 20),
                  Text(
                    'Rider Added a Stop',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(22).clamp(20.0, 26.0),
                      fontWeight: FontWeight.w700,
                      color: dashboard.primaryText,
                    ),
                  ),
                  ResponsiveGap(r.isCompact ? 8 : 10),
                  Text(
                    'The rider added a stop to this trip. Review the details below before continuing to pickup.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(14).clamp(13.0, 16.0),
                      color: dashboard.secondaryText,
                      height: 1.45,
                    ),
                  ),
                  ResponsiveGap(r.isCompact ? 14 : 18),
                  ...widget.notification.stops.map(
                    ( stop) => Padding(
                      padding: EdgeInsets.only(bottom: r.gap(10)),
                      child: _StopAddressCard(address: stop.address),
                    ),
                  ),
                  if (widget.notification.updatedFareDisplay != null) ...[
                    _StopDetailRow(
                      label: 'Updated fare',
                      value: widget.notification.updatedFareDisplay!,
                      highlight: true,
                    ),
                    ResponsiveGap(r.isCompact ? 14 : 18),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _dismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE3AA00),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: r.gap(14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.borderRadiusMd),
                        ),
                      ),
                      child: Text(
                        'Got it',
                        style: TextStyle(
                          fontFamily: AppFonts.satoshi,
                          fontSize: r.sp(16).clamp(15.0, 18.0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StopAddressCard extends StatelessWidget {
  const _StopAddressCard({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(14)),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
        border: Border.all(
          color: const Color(0xFFE3AA00).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: r.iconSm,
            color: const Color(0xFFE3AA00),
          ),
          SizedBox(width: r.gap(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Added stop',
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(11).clamp(10.0, 12.0),
                    color: dashboard.secondaryText,
                  ),
                ),
                SizedBox(height: r.gap(4)),
                Text(
                  address,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.bodyText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopDetailRow extends StatelessWidget {
  const _StopDetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(11).clamp(10.0, 12.0),
            color: dashboard.secondaryText,
          ),
        ),
        SizedBox(height: r.gap(4)),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(14).clamp(13.0, 16.0),
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            color: highlight ? const Color(0xFFE3AA00) : dashboard.bodyText,
          ),
        ),
      ],
    );
  }
}
