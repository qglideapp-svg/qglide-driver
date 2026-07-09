import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../config/dashboard_theme.dart';
import 'profile_avatar_image.dart';
import 'responsive_screen_shell.dart';

class RidePanelShell extends StatelessWidget {
  const RidePanelShell({
    required this.child,
    this.flatBackground = false,
    super.key,
  });

  final Widget child;
  final bool flatBackground;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: flatBackground ? dashboard.panelFill : null,
        borderRadius: BorderRadius.circular(r.borderRadiusLg),
        boxShadow: [
          BoxShadow(
            color: dashboard.panelShadow,
            blurRadius: r.gap(20),
            offset: Offset(0, r.gap(4)),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (!flatBackground)
            Positioned.fill(
              child: dashboard.panelImage(AppConstants.dashboardPanelAsset),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              r.gap(r.isCompact ? 16 : 20),
              r.gap(r.isCompact ? 16 : 20),
              r.gap(r.isCompact ? 16 : 20),
              r.gap(r.isCompact ? 12 : 16),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class RideRequestProfile extends StatefulWidget {
  const RideRequestProfile({
    super.key,
    this.riderName,
    this.riderRating,
    this.riderPhotoUrl,
    this.countdownDuration,
    this.onCountdownComplete,
  });

  final String? riderName;
  final double? riderRating;
  final String? riderPhotoUrl;
  final Duration? countdownDuration;
  final VoidCallback? onCountdownComplete;

  @override
  State<RideRequestProfile> createState() => _RideRequestProfileState();
}

class _RideRequestProfileState extends State<RideRequestProfile>
    with SingleTickerProviderStateMixin {
  AnimationController? _countdownController;
  var _countdownCompleted = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(covariant RideRequestProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.countdownDuration != oldWidget.countdownDuration) {
      _countdownController?.dispose();
      _countdownController = null;
      _countdownCompleted = false;
      _startCountdown();
    }
  }

  void _startCountdown() {
    final duration = widget.countdownDuration;
    if (duration == null) return;

    _countdownController = AnimationController(
      vsync: this,
      duration: duration,
    )
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed ||
            _countdownCompleted ||
            !mounted) {
          return;
        }

        _countdownCompleted = true;
        widget.onCountdownComplete?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _countdownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final avatarSize = r.w(r.isCompact ? 64 : 72).clamp(58.0, 82.0);
    final arcStrokeWidth = r.w(7).clamp(5.5, 9.0);
    final arcSize = avatarSize + arcStrokeWidth + r.gap(8);
    final resolvedPhoto = widget.riderPhotoUrl?.trim();

    final avatarImage = ProfileAvatarImage(
      size: avatarSize,
      avatarUrl: resolvedPhoto,
      displayName: widget.riderName,
    );

    return AnimatedBuilder(
      animation: _countdownController ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        final arcProgress = _countdownController?.value ?? 0.0;
        final countdownDuration = widget.countdownDuration;
        final remainingSeconds = countdownDuration == null
            ? 0
            : (countdownDuration.inSeconds -
                    countdownDuration.inSeconds * arcProgress)
                .ceil()
                .clamp(0, countdownDuration.inSeconds);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: arcSize,
              height: arcSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: avatarImage,
                    ),
                  ),
                  SizedBox(
                    width: arcSize,
                    height: arcSize,
                    child: CustomPaint(
                      painter: ProfileArcPainter(
                        color: AppColors.loginButton,
                        strokeWidth: arcStrokeWidth,
                        progress: arcProgress,
                        countdown: _countdownController != null,
                        trackColor: AppColors.loginButton.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  if (_countdownController != null && countdownDuration != null)
                    Container(
                      width: avatarSize * 0.46,
                      height: avatarSize * 0.46,
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
                          fontSize: r.sp(20).clamp(18.0, 24.0),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.riderName != null && widget.riderName!.isNotEmpty) ...[
              SizedBox(height: r.gap(10)),
              Text(
                widget.riderName!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(14).clamp(13.0, 16.0),
                  fontWeight: FontWeight.w600,
                  color: dashboard.primaryText,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class ProfileArcPainter extends CustomPainter {
  const ProfileArcPainter({
    required this.color,
    required this.strokeWidth,
    this.progress = 0,
    this.countdown = false,
    this.trackColor,
  });

  final Color color;
  final double strokeWidth;
  final double progress;
  final bool countdown;
  final Color? trackColor;

  static const _partialStartAngle = math.pi * 0.72;
  static const _partialSweep = math.pi * 1.55;
  static const _countdownStartAngle = -math.pi / 2;
  static const _fullSweep = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    if (countdown) {
      final trackPaint = Paint()
        ..color = trackColor ?? color.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, _countdownStartAngle, _fullSweep, false, trackPaint);

      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweep = _fullSweep * progress.clamp(0.0, 1.0);
      if (sweep > 0) {
        canvas.drawArc(
          rect,
          _countdownStartAngle,
          sweep,
          false,
          progressPaint,
        );
      }
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      _partialStartAngle,
      _partialSweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ProfileArcPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progress != progress ||
        oldDelegate.countdown != countdown ||
        oldDelegate.trackColor != trackColor;
  }
}

class RideLocationPill extends StatelessWidget {
  const RideLocationPill({
    required this.label,
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: r.gap(12),
        vertical: r.gap(8),
      ),
      decoration: BoxDecoration(
        color: dashboard.surface,
        borderRadius: BorderRadius.circular(r.gap(8)),
        border: Border.all(color: dashboard.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: r.iconSm,
            color: dashboard.mutedText,
          ),
          SizedBox(width: r.gap(6)),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(14).clamp(13.0, 16.0),
                fontWeight: FontWeight.w500,
                color: dashboard.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RidePickupTitle extends StatelessWidget {
  const RidePickupTitle({
    super.key,
    this.title = 'Pickup nearby',
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppFonts.satoshi,
        fontSize: r.sp(25).clamp(22.0, 28.0),
        fontWeight: FontWeight.w700,
        color: dashboard.primaryText,
        height: 1.2,
      ),
    );
  }
}

class RideLegProgressBar extends StatelessWidget {
  const RideLegProgressBar({
    required this.label,
    required this.progress,
    super.key,
  });

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final clamped = progress.clamp(0.0, 1.0);
    final percentLabel = '${(clamped * 100).round()}%';

    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(13).clamp(12.0, 14.0),
                fontWeight: FontWeight.w500,
                color: dashboard.secondaryText,
              ),
            ),
            const Spacer(),
            Text(
              percentLabel,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(13).clamp(12.0, 14.0),
                fontWeight: FontWeight.w600,
                color: dashboard.bodyText,
              ),
            ),
          ],
        ),
        ResponsiveGap(8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: r.h(8).clamp(6.0, 10.0),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: clamped),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: dashboard.pillBackground),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: const ColoredBox(color: Color(0xFFE3AA00)),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class RideContactIconButton extends StatelessWidget {
  const RideContactIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final size = r.w(44).clamp(40.0, 50.0);

    return Material(
      color: dashboard.card,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: r.iconMd,
            color: dashboard.mutedText,
          ),
        ),
      ),
    );
  }
}

class RideContactActionBar extends StatelessWidget {
  const RideContactActionBar({
    super.key,
    required this.onCall,
    required this.onMessage,
  });

  final VoidCallback onCall;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RideContactIconButton(
          icon: Icons.phone_rounded,
          onPressed: onCall,
        ),
        RideContactIconButton(
          icon: Icons.mail_outline_rounded,
          onPressed: onMessage,
        ),
      ],
    );
  }
}

class RideActionButton extends StatelessWidget {
  const RideActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.textColor = Colors.white,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final indicatorSize = r.sp(20).clamp(18.0, 22.0);

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(r.gap(10)),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(r.gap(10)),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.h(14)),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: indicatorSize,
                  height: indicatorSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: textColor,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(15).clamp(14.0, 17.0),
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
        ),
      ),
    );
  }
}
