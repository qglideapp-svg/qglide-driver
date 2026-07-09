import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../models/signup_performance_bonus.dart';

class SignupPerformanceBonusCard extends StatelessWidget {
  const SignupPerformanceBonusCard({
    super.key,
    required this.bonus,
  });

  final SignupPerformanceBonus bonus;

  @override
  Widget build(BuildContext context) {
    switch (bonus.status) {
      case SignupBonusStatus.paid:
        return _PaidBonusCard(bonus: bonus);
      case SignupBonusStatus.completed:
        return _CompletedBonusCard(bonus: bonus);
      case SignupBonusStatus.active:
      case SignupBonusStatus.expired:
      case SignupBonusStatus.ineligible:
        return _ActiveBonusCard(bonus: bonus);
    }
  }
}

class SignupPerformanceBonusSkeleton extends StatefulWidget {
  const SignupPerformanceBonusSkeleton({super.key});

  @override
  State<SignupPerformanceBonusSkeleton> createState() =>
      _SignupPerformanceBonusSkeletonState();
}

class _SignupPerformanceBonusSkeletonState
    extends State<SignupPerformanceBonusSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.35 + (_controller.value * 0.35);
        return Container(
          padding: EdgeInsets.all(r.gap(14)),
          decoration: BoxDecoration(
            color: dashboard.card,
            borderRadius: BorderRadius.circular(r.borderRadiusMd),
            border: Border.all(
              color: dashboard.mutedText.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBlock(
                    opacity: opacity,
                    width: r.w(44).clamp(40.0, 48.0),
                    height: r.w(44).clamp(40.0, 48.0),
                    borderRadius: 999,
                  ),
                  SizedBox(width: r.gap(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SkeletonBlock(
                                opacity: opacity,
                                height: r.sp(15).clamp(13.0, 17.0),
                                width: double.infinity,
                              ),
                            ),
                            SizedBox(width: r.gap(8)),
                            _SkeletonBlock(
                              opacity: opacity,
                              height: r.h(24).clamp(22.0, 28.0),
                              width: r.w(56).clamp(48.0, 64.0),
                              borderRadius: 999,
                            ),
                          ],
                        ),
                        SizedBox(height: r.gap(8)),
                        _SkeletonBlock(
                          opacity: opacity,
                          height: r.sp(14).clamp(13.0, 16.0),
                          width: double.infinity,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.gap(14)),
              Row(
                children: [
                  _SkeletonBlock(
                    opacity: opacity,
                    height: r.sp(15).clamp(14.0, 17.0),
                    width: r.w(110).clamp(96.0, 130.0),
                  ),
                  const Spacer(),
                  _SkeletonBlock(
                    opacity: opacity,
                    height: r.sp(13).clamp(12.0, 14.0),
                    width: r.w(48).clamp(40.0, 56.0),
                  ),
                ],
              ),
              SizedBox(height: r.gap(8)),
              _SkeletonBlock(
                opacity: opacity,
                height: r.h(8).clamp(6.0, 10.0),
                width: double.infinity,
                borderRadius: 999,
              ),
              SizedBox(height: r.gap(12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  4,
                  (_) => _SkeletonBlock(
                    opacity: opacity,
                    width: r.w(18).clamp(16.0, 20.0),
                    height: r.w(18).clamp(16.0, 20.0),
                    borderRadius: 999,
                  ),
                ),
              ),
              SizedBox(height: r.gap(12)),
              _SkeletonBlock(
                opacity: opacity,
                height: r.h(28).clamp(26.0, 32.0),
                width: r.w(120).clamp(104.0, 136.0),
                borderRadius: r.gap(8),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveBonusCard extends StatelessWidget {
  const _ActiveBonusCard({required this.bonus});

  final SignupPerformanceBonus bonus;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);
    final progress = bonus.progress;

    return Container(
      padding: EdgeInsets.all(r.gap(14)),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
        border: Border.all(
          color: AppColors.loginButton.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BonusIconBadge(progress: progress),
              SizedBox(width: r.gap(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.signupPerformanceBonusTitle,
                            textDirection: s.textDirection,
                            style: TextStyle(
                              fontFamily: AppFonts.satoshi,
                              fontSize: r.sp(15).clamp(13.0, 17.0),
                              fontWeight: FontWeight.w700,
                              color: dashboard.primaryText,
                              height: 1.25,
                            ),
                          ),
                        ),
                        _RewardPill(amountLabel: s.formatQar(bonus.bonusAmount)),
                      ],
                    ),
                    SizedBox(height: r.gap(4)),
                    Text(
                      s.signupPerformanceBonusSubtitle(
                        bonus.targetRides,
                        bonus.windowDays,
                      ),
                      textDirection: s.textDirection,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(14).clamp(13.0, 16.0),
                        color: dashboard.secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.gap(14)),
          Row(
            children: [
              Text(
                s.signupPerformanceBonusRidesLabel,
                textDirection: s.textDirection,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(15).clamp(14.0, 17.0),
                  fontWeight: FontWeight.w500,
                  color: dashboard.secondaryText,
                ),
              ),
              const Spacer(),
              Text(
                s.signupPerformanceBonusRideCount(
                  bonus.ridesCompleted,
                  bonus.targetRides,
                ),
                textDirection: s.textDirection,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(13).clamp(12.0, 14.0),
                  fontWeight: FontWeight.w700,
                  color: dashboard.bodyText,
                ),
              ),
            ],
          ),
          SizedBox(height: r.gap(8)),
          _AnimatedBonusProgressBar(progress: progress),
          SizedBox(height: r.gap(12)),
          _BonusMilestoneTrack(
            ridesCompleted: bonus.ridesCompleted,
            targetRides: bonus.targetRides,
          ),
          SizedBox(height: r.gap(12)),
          _BonusStatusFooter(bonus: bonus),
        ],
      ),
    );
  }
}

class _PaidBonusCard extends StatelessWidget {
  const _PaidBonusCard({required this.bonus});

  final SignupPerformanceBonus bonus;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);

    return Container(
      padding: EdgeInsets.all(r.gap(14)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.loginButton.withValues(alpha: 0.16),
            dashboard.card,
          ],
        ),
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
        border: Border.all(
          color: AppColors.loginButton.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: r.w(44).clamp(40.0, 48.0),
            height: r.w(44).clamp(40.0, 48.0),
            decoration: BoxDecoration(
              color: AppColors.loginButton.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.loginButton,
              size: r.sp(22).clamp(20.0, 24.0),
            ),
          ),
          SizedBox(width: r.gap(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.signupPerformanceBonusPaidTitle,
                  textDirection: s.textDirection,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                  ),
                ),
                SizedBox(height: r.gap(4)),
                Text(
                  s.signupPerformanceBonusPaidMessage(
                    s.formatQar(bonus.bonusAmount),
                  ),
                  textDirection: s.textDirection,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(11).clamp(10.0, 12.0),
                    color: dashboard.secondaryText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          _RewardPill(amountLabel: s.formatQar(bonus.bonusAmount)),
        ],
      ),
    );
  }
}

class _CompletedBonusCard extends StatelessWidget {
  const _CompletedBonusCard({required this.bonus});

  final SignupPerformanceBonus bonus;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);

    return Container(
      padding: EdgeInsets.all(r.gap(14)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.loginButton.withValues(alpha: 0.16),
            dashboard.card,
          ],
        ),
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
        border: Border.all(
          color: AppColors.loginButton.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: r.w(44).clamp(40.0, 48.0),
            height: r.w(44).clamp(40.0, 48.0),
            decoration: BoxDecoration(
              color: AppColors.loginButton.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: AppColors.loginButton,
              size: r.sp(24).clamp(22.0, 26.0),
            ),
          ),
          SizedBox(width: r.gap(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.signupPerformanceBonusCompletedTitle,
                  textDirection: s.textDirection,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                  ),
                ),
                SizedBox(height: r.gap(4)),
                Text(
                  s.signupPerformanceBonusCompletedMessage(
                    s.formatQar(bonus.bonusAmount),
                  ),
                  textDirection: s.textDirection,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(11).clamp(10.0, 12.0),
                    color: dashboard.secondaryText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          _RewardPill(amountLabel: s.formatQar(bonus.bonusAmount)),
        ],
      ),
    );
  }
}

class _BonusIconBadge extends StatelessWidget {
  const _BonusIconBadge({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final size = r.w(44).clamp(40.0, 48.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0.08, 1.0),
              strokeWidth: r.w(3).clamp(2.5, 3.5),
              backgroundColor: AppColors.loginButton.withValues(alpha: 0.14),
              color: AppColors.loginButton,
            ),
          ),
          Icon(
            Icons.emoji_events_rounded,
            color: AppColors.loginButton,
            size: r.sp(20).clamp(18.0, 22.0),
          ),
        ],
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.amountLabel});

  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.gap(10),
        vertical: r.gap(4),
      ),
      decoration: BoxDecoration(
        color: AppColors.loginButton,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        amountLabel,
        style: TextStyle(
          fontFamily: AppFonts.satoshi,
          fontSize: r.sp(11).clamp(10.0, 12.0),
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _AnimatedBonusProgressBar extends StatelessWidget {
  const _AnimatedBonusProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final clamped = progress.clamp(0.0, 1.0);

    return ClipRRect(
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
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFE3AA00),
                          Color(0xFFF0C84A),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BonusMilestoneTrack extends StatelessWidget {
  const _BonusMilestoneTrack({
    required this.ridesCompleted,
    required this.targetRides,
  });

  final int ridesCompleted;
  final int targetRides;

  @override
  Widget build(BuildContext context) {
    final milestones = SignupPerformanceBonus.milestoneRides
        .where((ride) => ride <= targetRides)
        .toList();

    if (milestones.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var index = 0; index < milestones.length; index++)
          _MilestoneDot(
            rideCount: milestones[index],
            isReached: ridesCompleted >= milestones[index],
            isCurrent: ridesCompleted < milestones[index] &&
                (index == 0 || ridesCompleted >= milestones[index - 1]),
          ),
      ],
    );
  }
}

class _MilestoneDot extends StatelessWidget {
  const _MilestoneDot({
    required this.rideCount,
    required this.isReached,
    required this.isCurrent,
  });

  final int rideCount;
  final bool isReached;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final dotColor = isReached
        ? AppColors.loginButton
        : isCurrent
            ? AppColors.loginButton.withValues(alpha: 0.35)
            : dashboard.pillBackground;

    return Column(
      children: [
        Container(
          width: r.w(18).clamp(16.0, 20.0),
          height: r.w(18).clamp(16.0, 20.0),
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: isCurrent && !isReached
                ? Border.all(color: AppColors.loginButton, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: isReached
              ? Icon(
                  Icons.check_rounded,
                  size: r.sp(11).clamp(10.0, 12.0),
                  color: Colors.white,
                )
              : null,
        ),
        SizedBox(height: r.gap(4)),
        Text(
          '$rideCount',
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(10).clamp(9.0, 11.0),
            fontWeight: isReached ? FontWeight.w700 : FontWeight.w500,
            color: isReached
                ? AppColors.loginButton
                : dashboard.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _BonusStatusFooter extends StatelessWidget {
  const _BonusStatusFooter({required this.bonus});

  final SignupPerformanceBonus bonus;

  @override
  Widget build(BuildContext context) {
    switch (bonus.status) {
      case SignupBonusStatus.active:
        return _DaysRemainingChip(daysRemaining: bonus.daysRemaining);
      case SignupBonusStatus.expired:
        return _StatusMessageChip(message: AppStringsScope.of(context).signupPerformanceBonusExpiredMessage);
      case SignupBonusStatus.ineligible:
        return _StatusMessageChip(message: AppStringsScope.of(context).signupPerformanceBonusIneligibleMessage);
      case SignupBonusStatus.completed:
      case SignupBonusStatus.paid:
        return const SizedBox.shrink();
    }
  }
}

class _StatusMessageChip extends StatelessWidget {
  const _StatusMessageChip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.gap(10),
        vertical: r.gap(6),
      ),
      decoration: BoxDecoration(
        color: dashboard.pillBackground,
        borderRadius: BorderRadius.circular(r.gap(8)),
      ),
      child: Text(
        message,
        textDirection: s.textDirection,
        style: TextStyle(
          fontFamily: AppFonts.satoshi,
          fontSize: r.sp(11).clamp(10.0, 12.0),
          fontWeight: FontWeight.w600,
          color: dashboard.secondaryText,
        ),
      ),
    );
  }
}

class _DaysRemainingChip extends StatelessWidget {
  const _DaysRemainingChip({required this.daysRemaining});

  final int daysRemaining;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.gap(10),
        vertical: r.gap(6),
      ),
      decoration: BoxDecoration(
        color: dashboard.pillBackground,
        borderRadius: BorderRadius.circular(r.gap(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: r.sp(14).clamp(13.0, 15.0),
            color: AppColors.loginButton,
          ),
          SizedBox(width: r.gap(6)),
          Text(
            s.signupPerformanceBonusDaysRemaining(daysRemaining),
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(11).clamp(10.0, 12.0),
              fontWeight: FontWeight.w600,
              color: dashboard.bodyText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.opacity,
    required this.height,
    this.width,
    this.borderRadius = 6,
  });

  final double opacity;
  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dashboard.mutedText.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
