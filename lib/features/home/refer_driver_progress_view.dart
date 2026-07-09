import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../config/app_strings.dart';
import '../../config/dashboard_theme.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_strings_scope.dart';
import '../../shared/widgets/responsive_screen_shell.dart';
import 'models/driver_referral_program_terms.dart';
import 'models/driver_referral_progress.dart';

class ReferDriverProgressView extends StatefulWidget {
  const ReferDriverProgressView({
    super.key,
    this.initialReferralCode = '',
  });

  final String initialReferralCode;

  @override
  State<ReferDriverProgressView> createState() =>
      _ReferDriverProgressViewState();
}

class _ReferDriverProgressViewState extends State<ReferDriverProgressView> {
  var _isInitialLoading = true;
  String? _errorMessage;
  DriverReferralProgress? _progress;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProgress(reset: true));
  }

  Future<void> _loadProgress({bool reset = false}) async {
    if (reset || _progress == null) {
      setState(() {
        _isInitialLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _errorMessage = null);
    }

    final response = await AuthService.getDriverIncentiveProgress();
    if (!mounted) return;

    final parsed = AuthService.extractDriverReferralProgress(response);
    if (parsed != null) {
      setState(() {
        _progress = parsed;
        _isInitialLoading = false;
      });
      return;
    }

    setState(() {
      _errorMessage = AuthService.extractErrorMessage(
        response,
        fallback: AppStrings.current().referDriverProgressLoadError,
      );
      _isInitialLoading = false;
    });
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStringsScope.of(context).referDriverCodeCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);
    final progress = _progress;
    final referralCode = (progress?.referralCode ?? widget.initialReferralCode)
        .trim();

    return Scaffold(
      backgroundColor: dashboard.screenBackground,
      appBar: AppBar(
        backgroundColor: dashboard.screenBackground,
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
          child: _isInitialLoading
              ? const _LazyReferralProgressContent()
              : _errorMessage != null
                  ? _ReferralProgressErrorState(
                      message: _errorMessage!,
                      onRetry: () => _loadProgress(reset: true),
                    )
                  : RefreshIndicator(
                      color: AppColors.loginButton,
                      onRefresh: _loadProgress,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          r.gap(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              s.referDriverProgressTitle,
                              textDirection: s.textDirection,
                              style: TextStyle(
                                fontFamily: AppFonts.satoshi,
                                fontSize: r.sp(27).clamp(24.0, 30.0),
                                fontWeight: FontWeight.w700,
                                color: dashboard.primaryText,
                                height: 1.15,
                              ),
                            ),
                            if (progress != null) ...[
                              Builder(
                                builder: (context) {
                                  final bountyLabel = s.formatQar(
                                    DriverReferralProgramTerms.bountyQar,
                                    decimals: 0,
                                  );
                                  final balanceReceivedLabel = s.formatQar(
                                    progress.totalBalanceCredited,
                                    decimals: 0,
                                  );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ResponsiveGap(8),
                                      Text(
                                        s.referDriverProgressSubtitle,
                                        textDirection: s.textDirection,
                                        style: TextStyle(
                                          fontFamily: AppFonts.satoshi,
                                          fontSize: r.sp(15).clamp(14.0, 16.0),
                                          color: dashboard.bodyText,
                                          height: 1.45,
                                        ),
                                      ),
                                      ResponsiveGap(20),
                                      _RewardSummaryCard(
                                        bountyLabel: bountyLabel,
                                      ),
                                      if (referralCode.isNotEmpty) ...[
                                        ResponsiveGap(14),
                                        _ReferralCodeCard(
                                          code: referralCode,
                                          onCopy: () => unawaited(
                                            _copyCode(referralCode),
                                          ),
                                        ),
                                      ],
                                      ResponsiveGap(14),
                                      _DetailsCard(
                                        title: s.referDriverYourProgress,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _StatTile(
                                                  label: s
                                                      .referDriverQualifiedReferrals,
                                                  value:
                                                      '${progress.qualifiedCount}',
                                                  hint: s
                                                      .referDriverQualifiedReferralsHint,
                                                ),
                                              ),
                                              SizedBox(width: r.gap(12)),
                                              Expanded(
                                                child: _StatTile(
                                                  label: s
                                                      .referDriverBalanceReceived,
                                                  value: balanceReceivedLabel,
                                                  hint: progress
                                                              .paidCommissionCount ==
                                                          0
                                                      ? s.referDriverNoBalanceCreditYet
                                                      : s.referDriverBalanceReceivedHint,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      ResponsiveGap(14),
                                      _DetailsCard(
                                        title: s.referDriverHowItWorks,
                                        children: [
                                          _StepRow(
                                            step: 1,
                                            label: s.referDriverHowItWorksStep1,
                                          ),
                                          ResponsiveGap(12),
                                          _StepRow(
                                            step: 2,
                                            label: s.referDriverHowItWorksStep2,
                                          ),
                                          ResponsiveGap(12),
                                          _StepRow(
                                            step: 3,
                                            label: s.referDriverHowItWorksStep3,
                                          ),
                                        ],
                                      ),
                                      if (progress.qualifiedCount == 0) ...[
                                        ResponsiveGap(14),
                                        const _EmptyReferralsCard(),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

class _RewardSummaryCard extends StatelessWidget {
  const _RewardSummaryCard({
    required this.bountyLabel,
  });

  final String bountyLabel;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(18)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.loginButton.withValues(alpha: 0.22),
            dashboard.card,
          ],
        ),
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
        border: Border.all(
          color: AppColors.loginButton.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.referDriverBalanceCredit,
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(14).clamp(13.0, 15.0),
              fontWeight: FontWeight.w600,
              color: dashboard.secondaryText,
            ),
          ),
          ResponsiveGap(8),
          Text(
            bountyLabel,
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(30).clamp(26.0, 34.0),
              fontWeight: FontWeight.w800,
              color: AppColors.loginButton,
            ),
          ),
          ResponsiveGap(8),
          Text(
            s.referDriverBalanceRewardSummary,
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(14).clamp(13.0, 15.0),
              color: dashboard.bodyText,
              height: 1.45,
            ),
          ),
          ResponsiveGap(8),
          Text(
            s.referDriverProgramRequirement,
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(13).clamp(12.0, 14.0),
              color: dashboard.secondaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  const _ReferralCodeCard({
    required this.code,
    required this.onCopy,
  });

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final cardColor =
        dashboard.isDark ? const Color(0xFF242118) : dashboard.card;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.referDriverYourCode,
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 18.0),
              fontWeight: FontWeight.w700,
              color: dashboard.primaryText,
            ),
          ),
          ResponsiveGap(12),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.gap(14),
              vertical: r.gap(12),
            ),
            decoration: BoxDecoration(
              color: dashboard.iconBox,
              borderRadius: BorderRadius.circular(r.gap(10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(22).clamp(20.0, 24.0),
                      fontWeight: FontWeight.w800,
                      color: AppColors.loginButton,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: s.referDriverCopyCode,
                  onPressed: onCopy,
                  icon: Icon(
                    Icons.copy_rounded,
                    color: dashboard.secondaryText,
                    size: r.sp(20).clamp(18.0, 22.0),
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

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final cardColor =
        dashboard.isDark ? const Color(0xFF242118) : dashboard.card;

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
            textDirection: AppStringsScope.of(context).textDirection,
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);

    return Container(
      padding: EdgeInsets.all(r.gap(12)),
      decoration: BoxDecoration(
        color: dashboard.iconBox,
        borderRadius: BorderRadius.circular(r.gap(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(12).clamp(11.0, 13.0),
              color: dashboard.secondaryText,
              height: 1.3,
            ),
          ),
          ResponsiveGap(6),
          Text(
            value,
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(26).clamp(22.0, 30.0),
              fontWeight: FontWeight.w800,
              color: dashboard.primaryText,
            ),
          ),
          ResponsiveGap(6),
          Text(
            hint,
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(11).clamp(10.0, 12.0),
              color: dashboard.mutedText,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.label,
  });

  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: r.w(28).clamp(24.0, 32.0),
          height: r.w(28).clamp(24.0, 32.0),
          decoration: BoxDecoration(
            color: AppColors.loginButton.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(13).clamp(12.0, 14.0),
              fontWeight: FontWeight.w700,
              color: AppColors.loginButton,
            ),
          ),
        ),
        SizedBox(width: r.gap(12)),
        Expanded(
          child: Text(
            label,
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(14).clamp(13.0, 15.0),
              color: dashboard.bodyText,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyReferralsCard extends StatelessWidget {
  const _EmptyReferralsCard();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(20)),
      decoration: BoxDecoration(
        color: dashboard.iconBox,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Text(
        s.referDriverNoReferralsYet,
        textAlign: TextAlign.center,
        textDirection: s.textDirection,
        style: TextStyle(
          fontFamily: AppFonts.satoshi,
          fontSize: r.sp(14).clamp(13.0, 15.0),
          color: dashboard.secondaryText,
          height: 1.45,
        ),
      ),
    );
  }
}

class _ReferralProgressErrorState extends StatelessWidget {
  const _ReferralProgressErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: dashboard.secondaryText,
            size: r.iconMd,
          ),
          ResponsiveGap(12),
          Text(
            message,
            textAlign: TextAlign.center,
            textDirection: s.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 18.0),
              color: dashboard.bodyText,
            ),
          ),
          ResponsiveGap(16),
          TextButton(
            onPressed: () => unawaited(onRetry()),
            child: Text(s.tryAgain),
          ),
        ],
      ),
    );
  }
}

class _LazyReferralProgressContent extends StatefulWidget {
  const _LazyReferralProgressContent();

  @override
  State<_LazyReferralProgressContent> createState() =>
      _LazyReferralProgressContentState();
}

class _LazyReferralProgressContentState
    extends State<_LazyReferralProgressContent>
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

  Widget _lazyCard({
    required Color cardColor,
    required AppResponsive r,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(16)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);
    final cardColor = dashboard.isDark
        ? const Color(0xFF242118)
        : dashboard.card;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            r.gap(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LazyBlock(
                opacity: opacity,
                color: dashboard.primaryText,
                height: r.sp(27).clamp(24.0, 30.0),
                width: r.w(180).clamp(150.0, 220.0),
                borderRadius: r.gap(8),
              ),
              ResponsiveGap(8),
              _LazyBlock(
                opacity: opacity,
                color: dashboard.bodyText,
                height: r.sp(15).clamp(14.0, 16.0),
                width: double.infinity,
                borderRadius: r.gap(6),
              ),
              ResponsiveGap(6),
              _LazyBlock(
                opacity: opacity,
                color: dashboard.bodyText,
                height: r.sp(15).clamp(14.0, 16.0),
                width: r.w(240).clamp(200.0, 280.0),
                borderRadius: r.gap(6),
              ),
              ResponsiveGap(20),
              _lazyCard(
                cardColor: cardColor,
                r: r,
                children: [
                  _LazyBlock(
                    opacity: opacity,
                    color: dashboard.secondaryText,
                    height: r.sp(14).clamp(13.0, 15.0),
                    width: r.w(110).clamp(90.0, 130.0),
                    borderRadius: r.gap(6),
                  ),
                  ResponsiveGap(10),
                  _LazyBlock(
                    opacity: opacity,
                    color: AppColors.loginButton,
                    height: r.sp(30).clamp(26.0, 34.0),
                    width: r.w(120).clamp(96.0, 140.0),
                    borderRadius: r.gap(8),
                  ),
                  ResponsiveGap(8),
                  _LazyBlock(
                    opacity: opacity,
                    color: dashboard.bodyText,
                    height: r.sp(14).clamp(13.0, 15.0),
                    width: double.infinity,
                    borderRadius: r.gap(6),
                  ),
                  ResponsiveGap(8),
                  _LazyBlock(
                    opacity: opacity,
                    color: dashboard.secondaryText,
                    height: r.sp(13).clamp(12.0, 14.0),
                    width: r.w(260).clamp(220.0, 300.0),
                    borderRadius: r.gap(6),
                  ),
                ],
              ),
              ResponsiveGap(14),
              _lazyCard(
                cardColor: cardColor,
                r: r,
                children: [
                  _LazyBlock(
                    opacity: opacity,
                    color: dashboard.primaryText,
                    height: r.sp(16).clamp(15.0, 18.0),
                    width: r.w(96).clamp(80.0, 110.0),
                    borderRadius: r.gap(6),
                  ),
                  ResponsiveGap(12),
                  _LazyBlock(
                    opacity: opacity,
                    color: dashboard.iconBox,
                    height: r.h(52).clamp(48.0, 56.0),
                    width: double.infinity,
                    borderRadius: r.gap(10),
                  ),
                ],
              ),
              ResponsiveGap(14),
              _lazyCard(
                cardColor: cardColor,
                r: r,
                children: [
                  _LazyBlock(
                    opacity: opacity,
                    color: dashboard.primaryText,
                    height: r.sp(16).clamp(15.0, 18.0),
                    width: r.w(120).clamp(100.0, 140.0),
                    borderRadius: r.gap(6),
                  ),
                  ResponsiveGap(14),
                  Row(
                    children: [
                      Expanded(
                        child: _LazyBlock(
                          opacity: opacity,
                          color: dashboard.iconBox,
                          height: r.gap(108),
                          width: double.infinity,
                          borderRadius: r.gap(10),
                        ),
                      ),
                      SizedBox(width: r.gap(12)),
                      Expanded(
                        child: _LazyBlock(
                          opacity: opacity,
                          color: dashboard.iconBox,
                          height: r.gap(108),
                          width: double.infinity,
                          borderRadius: r.gap(10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ResponsiveGap(14),
              _lazyCard(
                cardColor: cardColor,
                r: r,
                children: [
                  _LazyBlock(
                    opacity: opacity,
                    color: dashboard.primaryText,
                    height: r.sp(16).clamp(15.0, 18.0),
                    width: r.w(120).clamp(100.0, 140.0),
                    borderRadius: r.gap(6),
                  ),
                  ResponsiveGap(14),
                  ...List.generate(3, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == 2 ? 0 : r.gap(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LazyBlock(
                            opacity: opacity,
                            color: AppColors.loginButton,
                            height: r.w(28).clamp(24.0, 32.0),
                            width: r.w(28).clamp(24.0, 32.0),
                            borderRadius: 999,
                          ),
                          SizedBox(width: r.gap(12)),
                          Expanded(
                            child: _LazyBlock(
                              opacity: opacity,
                              color: dashboard.bodyText,
                              height: r.sp(14).clamp(13.0, 15.0),
                              width: double.infinity,
                              borderRadius: r.gap(6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
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
    this.borderRadius = 999,
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
