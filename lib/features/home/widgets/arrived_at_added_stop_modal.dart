import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../services/added_stop_arrival_sound_service.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../../../shared/widgets/ride_panel_shared.dart';
import '../models/nearby_ride_offer.dart';

class ArrivedAtAddedStopModal extends StatefulWidget {
  const ArrivedAtAddedStopModal({
    super.key,
    required this.notification,
    required this.onOpenWaze,
    required this.countdownDuration,
  });

  final AddedStopArrivalNotification notification;
  final Future<String?> Function() onOpenWaze;
  final Duration countdownDuration;

  static Future<void> show(
    BuildContext context, {
    required AddedStopArrivalNotification notification,
    required Future<String?> Function() onOpenWaze,
    Duration countdownDuration =
        AppConstants.addedStopArrivalNotificationDuration,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => ArrivedAtAddedStopModal(
        notification: notification,
        onOpenWaze: onOpenWaze,
        countdownDuration: countdownDuration,
      ),
    );
  }

  @override
  State<ArrivedAtAddedStopModal> createState() =>
      _ArrivedAtAddedStopModalState();
}

class _ArrivedAtAddedStopModalState extends State<ArrivedAtAddedStopModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdownController;
  var _countdownCompleted = false;
  var _isOpeningWaze = false;

  @override
  void initState() {
    super.initState();
    unawaited(AddedStopArrivalSoundService.play());
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
        unawaited(_dismiss());
      })
      ..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openWaze());
    });
  }

  @override
  void dispose() {
    unawaited(AddedStopArrivalSoundService.stop());
    _countdownController.dispose();
    super.dispose();
  }

  Future<void> _openWaze() async {
    if (_isOpeningWaze || !mounted) return;

    setState(() => _isOpeningWaze = true);
    final error = await widget.onOpenWaze();
    if (!mounted) return;

    setState(() => _isOpeningWaze = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  Future<void> _dismiss() async {
    await AddedStopArrivalSoundService.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
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
                            color: Color(0xFFE8F8EE),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.place_rounded,
                            size: r.iconMd,
                            color: const Color(0xFF049327),
                          ),
                        ),
                        SizedBox(
                          width: arcSize,
                          height: arcSize,
                          child: CustomPaint(
                            painter: ProfileArcPainter(
                              color: const Color(0xFF049327),
                              strokeWidth: arcStrokeWidth,
                              progress: _countdownController.value,
                              countdown: true,
                              trackColor: const Color(0xFF049327)
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
                    s.arrivedAtAddedStop,
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
                    s.arrivedAtAddedStopMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(14).clamp(13.0, 16.0),
                      color: dashboard.secondaryText,
                      height: 1.45,
                    ),
                  ),
                  ResponsiveGap(r.isCompact ? 14 : 18),
                  _StopAddressCard(
                    label: s.addedStop,
                    address: widget.notification.stop.address,
                  ),
                  ResponsiveGap(10),
                  _StopAddressCard(
                    label: s.finalDestination,
                    address: widget.notification.finalDestination,
                    muted: true,
                  ),
                  ResponsiveGap(r.isCompact ? 14 : 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isOpeningWaze ? null : () => unawaited(_openWaze()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF049327),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: r.gap(14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.borderRadiusMd),
                        ),
                      ),
                      child: _isOpeningWaze
                          ? SizedBox(
                              width: r.iconSm,
                              height: r.iconSm,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              s.openWithWaze,
                              style: TextStyle(
                                fontFamily: AppFonts.satoshi,
                                fontSize: r.sp(16).clamp(15.0, 18.0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  ResponsiveGap(10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => unawaited(_dismiss()),
                      child: Text(
                        s.gotIt,
                        style: TextStyle(
                          fontFamily: AppFonts.satoshi,
                          fontSize: r.sp(15).clamp(14.0, 17.0),
                          fontWeight: FontWeight.w600,
                          color: dashboard.secondaryText,
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
  const _StopAddressCard({
    required this.label,
    required this.address,
    this.muted = false,
  });

  final String label;
  final String address;
  final bool muted;

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
          color: muted
              ? dashboard.borderSubtle
              : const Color(0xFF049327).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
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
            address,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(14).clamp(13.0, 16.0),
              fontWeight: FontWeight.w700,
              color: muted ? dashboard.secondaryText : dashboard.bodyText,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
