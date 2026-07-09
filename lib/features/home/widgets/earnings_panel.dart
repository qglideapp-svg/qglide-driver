import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_strings.dart';
import '../../../config/dashboard_theme.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../models/driver_completed_trip.dart';
import '../models/driver_wallet_balance.dart';
import '../models/signup_performance_bonus.dart';
import 'signup_performance_bonus_card.dart';

class EarningsPanel extends StatefulWidget {
  const EarningsPanel({
    super.key,
    required this.onTopUp,
    required this.onWithdrawal,
    required this.onRefer,
    this.isLoading = false,
    this.isLoadingSignupBonus = false,
    this.isLoadingReferDriver = false,
    this.isReferEnabled = true,
    this.wallet,
    this.signupPerformanceBonus,
    this.completedTrips = const [],
    this.isLoadingCompletedTrips = false,
    this.completedTripsCurrentPage = 1,
    this.completedTripsTotalPages = 1,
    this.canGoToPreviousTripsPage = false,
    this.completedTripsHasMore = false,
    this.onNextTripsPage,
    this.onPreviousTripsPage,
    this.onRefresh,
  });

  final VoidCallback onTopUp;
  final VoidCallback onWithdrawal;
  final VoidCallback onRefer;
  final bool isLoading;
  final bool isLoadingSignupBonus;
  final bool isLoadingReferDriver;
  final bool isReferEnabled;
  final DriverWalletBalance? wallet;
  final SignupPerformanceBonus? signupPerformanceBonus;
  final List<DriverCompletedTrip> completedTrips;
  final bool isLoadingCompletedTrips;
  final int completedTripsCurrentPage;
  final int completedTripsTotalPages;
  final bool canGoToPreviousTripsPage;
  final bool completedTripsHasMore;
  final VoidCallback? onNextTripsPage;
  final VoidCallback? onPreviousTripsPage;
  final Future<void> Function()? onRefresh;

  @override
  State<EarningsPanel> createState() => _EarningsPanelState();
}

class _EarningsPanelState extends State<EarningsPanel> {
  var _balanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final wallet = widget.wallet;
    final dashboard = DashboardTheme.of(context);

    if (widget.isLoading && wallet == null) {
      return _EarningsRefreshScroll(
        onRefresh: widget.onRefresh,
        child: const _LazyEarningsPanel(),
      );
    }

    return _EarningsRefreshScroll(
      onRefresh: widget.onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              r.gap(16),
              0,
              r.gap(16),
              r.gap(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BalanceHeader(
                  balanceVisible: _balanceVisible,
                  totalBalance: wallet?.primaryBalance ?? 0,
                  onToggleVisibility: () {
                    setState(() => _balanceVisible = !_balanceVisible);
                  },
                ),
                SizedBox(height: r.gap(14)),
                _ActionButtonsRow(
                  onTopUp: widget.onTopUp,
                  onWithdrawal: widget.onWithdrawal,
                  onRefer: widget.onRefer,
                  isReferLoading: widget.isLoadingReferDriver,
                  isReferEnabled: widget.isReferEnabled,
                ),
                if (widget.isLoadingSignupBonus) ...[
                  SizedBox(height: r.gap(16)),
                  const SignupPerformanceBonusSkeleton(),
                ] else if (widget.signupPerformanceBonus != null) ...[
                  SizedBox(height: r.gap(16)),
                  SignupPerformanceBonusCard(
                    bonus: widget.signupPerformanceBonus!,
                  ),
                ],
                SizedBox(height: r.gap(18)),
                _SectionHeading(title: s.walletBalance),
                SizedBox(height: r.gap(10)),
                _WalletBalanceGrid(
                  balanceVisible: _balanceVisible,
                  rawBalance: wallet?.rawBalance ?? 0,
                  verifiedBalance: wallet?.verifiedBalance ?? 0,
                  pendingWithdrawals: wallet?.pendingWithdrawals ?? 0,
                  negativeBalance: wallet?.negativeBalance ?? 0,
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(r.borderRadiusLg),
              topRight: Radius.circular(r.borderRadiusLg),
            ),
            child: ColoredBox(
              color: dashboard.completedTripsBg,
              child: _CompletedTripsSection(
                trips: widget.completedTrips,
                isLoading: widget.isLoadingCompletedTrips,
                currentPage: widget.completedTripsCurrentPage,
                totalPages: widget.completedTripsTotalPages,
                canGoPrevious: widget.canGoToPreviousTripsPage,
                hasMore: widget.completedTripsHasMore,
                onPrevious: widget.onPreviousTripsPage,
                onNext: widget.onNextTripsPage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsRefreshScroll extends StatelessWidget {
  const _EarningsRefreshScroll({
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function()? onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.loginButton,
      onRefresh: onRefresh ?? () async {},
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

TextStyle balanceAmountTextStyle(AppResponsive r, Color color) {
  return TextStyle(
    fontFamily: AppFonts.satoshi,
    fontSize: r.sp(30).clamp(26.0, 34.0),
    fontWeight: FontWeight.w900,
    color: color,
    height: 1.15,
  );
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.balanceVisible,
    required this.totalBalance,
    required this.onToggleVisibility,
  });

  final bool balanceVisible;
  final double totalBalance;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              s.formatTodayDate(),
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(13).clamp(12.0, 14.0),
                color: dashboard.secondaryText,
              ),
            ),
            SizedBox(width: r.gap(6)),
            InkWell(
              onTap: onToggleVisibility,
              borderRadius: BorderRadius.circular(r.gap(8)),
              child: Padding(
                padding: EdgeInsets.all(r.gap(2)),
                child: Icon(
                  balanceVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: r.iconSm,
                  color: dashboard.mutedText,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.gap(6)),
        Text(
          balanceVisible ? formatQar(totalBalance) : s.hiddenBalanceFull,
          textAlign: TextAlign.center,
          style: balanceAmountTextStyle(r, dashboard.primaryText),
        ),
      ],
    );
  }
}

class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow({
    required this.onTopUp,
    required this.onWithdrawal,
    required this.onRefer,
    this.isReferLoading = false,
    this.isReferEnabled = true,
  });

  final VoidCallback onTopUp;
  final VoidCallback onWithdrawal;
  final VoidCallback onRefer;
  final bool isReferLoading;
  final bool isReferEnabled;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final gap = r.gap(12);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: _EarningsIconActionButton(
            label: s.topUp,
            iconAsset: AppConstants.topUpIconAsset,
            onPressed: onTopUp,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _EarningsIconActionButton(
            label: s.withdrawal,
            iconAsset: AppConstants.withdrawalIconAsset,
            onPressed: onWithdrawal,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _EarningsIconActionButton(
            label: s.referAFriend,
            icon: Icons.card_giftcard_rounded,
            isLoading: isReferLoading,
            onPressed: isReferEnabled ? onRefer : null,
          ),
        ),
      ],
    );
  }
}

class _EarningsIconActionButton extends StatelessWidget {
  const _EarningsIconActionButton({
    required this.label,
    this.iconAsset,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
  }) : assert(iconAsset != null || icon != null);

  final String label;
  final String? iconAsset;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final boxSize = r.w(64).clamp(56.0, 72.0);
    final dashboard = DashboardTheme.of(context);
    final enabled = onPressed != null && !isLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: dashboard.walletCard,
          borderRadius: BorderRadius.circular(r.borderRadiusMd),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(r.borderRadiusMd),
            child: Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.borderRadiusMd),
                border: Border.all(color: dashboard.walletCardBorder),
              ),
              alignment: Alignment.center,
              child: isLoading
                  ? SizedBox(
                      width: r.w(22).clamp(20.0, 24.0),
                      height: r.w(22).clamp(20.0, 24.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.loginButton.withValues(
                          alpha: enabled ? 1 : 0.45,
                        ),
                      ),
                    )
                  : iconAsset != null
                      ? Image.asset(
                          iconAsset!,
                          width: r.w(26).clamp(22.0, 28.0),
                          height: r.w(26).clamp(22.0, 28.0),
                          fit: BoxFit.contain,
                          color: enabled
                              ? null
                              : dashboard.mutedText.withValues(alpha: 0.5),
                          colorBlendMode:
                              enabled ? null : BlendMode.srcIn,
                        )
                      : Icon(
                          icon,
                          size: r.w(26).clamp(22.0, 28.0),
                          color: enabled
                              ? AppColors.loginButton
                              : dashboard.mutedText.withValues(alpha: 0.45),
                        ),
            ),
          ),
        ),
        SizedBox(height: r.gap(6)),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(13).clamp(12.0, 15.0),
            fontWeight: FontWeight.w600,
            color: dashboard.primaryText.withValues(
              alpha: enabled ? 0.75 : 0.45,
            ),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Text(
      title,
      style: TextStyle(
        fontFamily: AppFonts.satoshi,
        fontSize: r.sp(16).clamp(15.0, 18.0),
        fontWeight: FontWeight.w700,
        color: dashboard.primaryText,
      ),
    );
  }
}

class _WalletBalanceGrid extends StatelessWidget {
  const _WalletBalanceGrid({
    required this.balanceVisible,
    required this.rawBalance,
    required this.verifiedBalance,
    required this.pendingWithdrawals,
    required this.negativeBalance,
  });

  final bool balanceVisible;
  final double rawBalance;
  final double verifiedBalance;
  final double pendingWithdrawals;
  final double negativeBalance;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final gap = r.gap(10);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _WalletBalanceCard(
                label: s.rawBalance,
                iconAsset: AppConstants.rawBalanceIconAsset,
                amount: rawBalance,
                balanceVisible: balanceVisible,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _WalletBalanceCard(
                label: s.verifiedBalance,
                iconAsset: AppConstants.verifiedBalanceIconAsset,
                amount: verifiedBalance,
                balanceVisible: balanceVisible,
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _WalletBalanceCard(
                label: s.pendingWithdrawals,
                iconAsset: AppConstants.pendingWithdrawalsIconAsset,
                amount: pendingWithdrawals,
                balanceVisible: balanceVisible,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _WalletBalanceCard(
                label: s.negativeBalance,
                iconAsset: AppConstants.negativeBalanceIconAsset,
                amount: negativeBalance,
                balanceVisible: balanceVisible,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({
    required this.label,
    required this.iconAsset,
    required this.amount,
    required this.balanceVisible,
  });

  final String label;
  final String iconAsset;
  final double amount;
  final bool balanceVisible;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Container(
      padding: EdgeInsets.all(r.gap(10)),
      decoration: BoxDecoration(
        color: dashboard.walletCard,
        borderRadius: BorderRadius.circular(r.gap(12)),
        border: Border.all(color: dashboard.walletCardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: r.w(32).clamp(28.0, 36.0),
            height: r.w(32).clamp(28.0, 36.0),
            decoration: BoxDecoration(
              color: AppColors.loginButton.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(r.gap(8)),
            ),
            child: Center(
              child: Image.asset(
                iconAsset,
                width: r.iconSm,
                height: r.iconSm,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(width: r.gap(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(12).clamp(11.0, 13.0),
                    color: dashboard.secondaryText,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: r.gap(4)),
                Text(
                  balanceVisible ? formatQar(amount) : s.hiddenBalanceShort,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(15).clamp(14.0, 16.0),
                    fontWeight: FontWeight.w900,
                    color: dashboard.primaryText,
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

class _CompletedTripsSection extends StatelessWidget {
  const _CompletedTripsSection({
    required this.trips,
    required this.isLoading,
    required this.currentPage,
    required this.totalPages,
    required this.canGoPrevious,
    required this.hasMore,
    this.onPrevious,
    this.onNext,
  });

  final List<DriverCompletedTrip> trips;
  final bool isLoading;
  final int currentPage;
  final int totalPages;
  final bool canGoPrevious;
  final bool hasMore;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            r.gap(14),
            r.gap(16),
            r.gap(14),
            r.gap(10),
          ),
          child: _SectionHeading(title: s.completedTrips),
        ),
        if (isLoading && trips.isEmpty)
          const _LazyCompletedTripsList()
        else if (trips.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.gap(14),
              vertical: r.h(48),
            ),
            child: Center(
              child: Text(
                s.noCompletedTripsYet,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(15).clamp(14.0, 16.0),
                  color: dashboard.mutedText,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.fromLTRB(
              r.gap(14),
              0,
              r.gap(14),
              r.gap(8),
            ),
            child: Column(
              children: trips
                  .map(
                    (trip) => Padding(
                      padding: EdgeInsets.only(bottom: r.gap(8)),
                      child: _CompletedTripRow(trip: trip),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (trips.isNotEmpty || canGoPrevious || hasMore)
          _TripsPaginationBar(
            currentPage: currentPage,
            totalPages: totalPages,
            canGoPrevious: canGoPrevious,
            hasMore: hasMore,
            isLoading: isLoading,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
      ],
    );
  }
}

class _TripsPaginationBar extends StatelessWidget {
  const _TripsPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.canGoPrevious,
    required this.hasMore,
    required this.isLoading,
    this.onPrevious,
    this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final bool canGoPrevious;
  final bool hasMore;
  final bool isLoading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.gap(14),
        r.gap(8),
        r.gap(14),
        r.gap(14),
      ),
      child: Row(
        children: [
          _PaginationButton(
            label: s.previous,
            enabled: canGoPrevious && !isLoading,
            onTap: onPrevious,
          ),
          Expanded(
            child: Text(
              s.pageOf(currentPage, totalPages),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(14).clamp(13.0, 15.0),
                fontWeight: FontWeight.w600,
                color: dashboard.secondaryText,
              ),
            ),
          ),
          _PaginationButton(
            label: s.next,
            enabled: hasMore && !isLoading,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final color = enabled ? AppColors.loginButton : dashboard.mutedText;

    return TextButton(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: r.gap(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.satoshi,
          fontSize: r.sp(14).clamp(13.0, 15.0),
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _CompletedTripRow extends StatelessWidget {
  const _CompletedTripRow({required this.trip});

  final DriverCompletedTrip trip;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final amount = trip.amount;
    final amountDecimals = amount == amount.roundToDouble() ? 0 : 2;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(12)),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.circular(r.gap(12)),
      ),
      child: Row(
        children: [
          Container(
            width: r.w(44).clamp(40.0, 48.0),
            height: r.w(44).clamp(40.0, 48.0),
            decoration: BoxDecoration(
              color: const Color(0x1FE3AA00),
              borderRadius: BorderRadius.circular(r.gap(10)),
            ),
            child: Center(
              child: Image.asset(
                AppConstants.driverTabIconAsset,
                width: r.iconSm,
                height: r.iconSm,
                fit: BoxFit.contain,
                color: AppColors.loginButton,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(width: r.gap(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.locationDisplay,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(16).clamp(15.0, 18.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                  ),
                ),
                SizedBox(height: r.gap(2)),
                Text(
                  trip.dateTimeDisplay,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(13).clamp(12.0, 14.0),
                    color: dashboard.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+ ${formatQar(amount, decimals: amountDecimals)}',
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(16).clamp(15.0, 18.0),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF049327),
                ),
              ),
              SizedBox(height: r.gap(2)),
              Text(
                trip.distanceDisplay,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(13).clamp(12.0, 14.0),
                  color: dashboard.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String formatQar(double amount, {int decimals = 2}) {
  return AppStrings.current().formatQar(amount, decimals: decimals);
}

class LazyBalanceHeader extends StatefulWidget {
  const LazyBalanceHeader({super.key});

  @override
  State<LazyBalanceHeader> createState() => _LazyBalanceHeaderState();
}

class _LazyBalanceHeaderState extends State<LazyBalanceHeader>
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

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return Column(
          children: [
            _LazyPlaceholder(
              opacity: opacity,
              color: dashboard.secondaryText,
              height: r.sp(13).clamp(12.0, 14.0),
              width: r.w(96).clamp(80.0, 110.0),
            ),
            SizedBox(height: r.gap(10)),
            _LazyPlaceholder(
              opacity: opacity,
              color: dashboard.primaryText,
              height: r.sp(30).clamp(26.0, 34.0),
              width: r.w(180).clamp(150.0, 220.0),
              borderRadius: r.gap(8),
            ),
          ],
        );
      },
    );
  }
}

class _LazyEarningsPanel extends StatefulWidget {
  const _LazyEarningsPanel();

  @override
  State<_LazyEarningsPanel> createState() => _LazyEarningsPanelState();
}

class _LazyEarningsPanelState extends State<_LazyEarningsPanel>
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

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                r.gap(16),
                0,
                r.gap(16),
                r.gap(16),
              ),
              child: Column(
                children: [
                  _LazyPlaceholder(
                    opacity: opacity,
                    color: dashboard.secondaryText,
                    height: r.sp(13).clamp(12.0, 14.0),
                    width: r.w(96).clamp(80.0, 110.0),
                  ),
                  SizedBox(height: r.gap(10)),
                  _LazyPlaceholder(
                    opacity: opacity,
                    color: dashboard.primaryText,
                    height: r.sp(30).clamp(26.0, 34.0),
                    width: r.w(180).clamp(150.0, 220.0),
                    borderRadius: r.gap(8),
                  ),
                  SizedBox(height: r.gap(18)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LazyPlaceholder(
                        opacity: opacity,
                        color: dashboard.card,
                        height: r.w(64).clamp(56.0, 72.0),
                        width: r.w(64).clamp(56.0, 72.0),
                        borderRadius: r.borderRadiusMd,
                      ),
                      SizedBox(width: r.gap(12)),
                      _LazyPlaceholder(
                        opacity: opacity,
                        color: dashboard.card,
                        height: r.w(64).clamp(56.0, 72.0),
                        width: r.w(64).clamp(56.0, 72.0),
                        borderRadius: r.borderRadiusMd,
                      ),
                      SizedBox(width: r.gap(12)),
                      _LazyPlaceholder(
                        opacity: opacity,
                        color: dashboard.card,
                        height: r.w(64).clamp(56.0, 72.0),
                        width: r.w(64).clamp(56.0, 72.0),
                        borderRadius: r.borderRadiusMd,
                      ),
                    ],
                  ),
                  SizedBox(height: r.gap(16)),
                  const SignupPerformanceBonusSkeleton(),
                  SizedBox(height: r.gap(18)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _LazyPlaceholder(
                      opacity: opacity,
                      color: dashboard.primaryText,
                      height: r.sp(16).clamp(15.0, 18.0),
                      width: r.w(120).clamp(100.0, 140.0),
                      borderRadius: r.gap(6),
                    ),
                  ),
                  SizedBox(height: r.gap(12)),
                  Row(
                    children: [
                      Expanded(
                        child: _LazyWalletCardPlaceholder(
                          opacity: opacity,
                          dashboard: dashboard,
                          r: r,
                        ),
                      ),
                      SizedBox(width: r.gap(10)),
                      Expanded(
                        child: _LazyWalletCardPlaceholder(
                          opacity: opacity,
                          dashboard: dashboard,
                          r: r,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.gap(10)),
                  Row(
                    children: [
                      Expanded(
                        child: _LazyWalletCardPlaceholder(
                          opacity: opacity,
                          dashboard: dashboard,
                          r: r,
                        ),
                      ),
                      SizedBox(width: r.gap(10)),
                      Expanded(
                        child: _LazyWalletCardPlaceholder(
                          opacity: opacity,
                          dashboard: dashboard,
                          r: r,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r.borderRadiusLg),
                topRight: Radius.circular(r.borderRadiusLg),
              ),
              child: ColoredBox(
                color: dashboard.completedTripsBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        r.gap(14),
                        r.gap(16),
                        r.gap(14),
                        r.gap(10),
                      ),
                      child: _LazyPlaceholder(
                        opacity: opacity,
                        color: dashboard.primaryText,
                        height: r.sp(16).clamp(15.0, 18.0),
                        width: r.w(140).clamp(120.0, 160.0),
                        borderRadius: r.gap(6),
                      ),
                    ),
                    const _LazyCompletedTripsList(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LazyWalletCardPlaceholder extends StatelessWidget {
  const _LazyWalletCardPlaceholder({
    required this.opacity,
    required this.dashboard,
    required this.r,
  });

  final double opacity;
  final DashboardTheme dashboard;
  final AppResponsive r;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.gap(10)),
      decoration: BoxDecoration(
        color: dashboard.walletCard,
        borderRadius: BorderRadius.circular(r.gap(12)),
        border: Border.all(color: dashboard.walletCardBorder),
      ),
      child: Row(
        children: [
          _LazyPlaceholder(
            opacity: opacity,
            color: dashboard.secondaryText,
            height: r.w(32).clamp(28.0, 36.0),
            width: r.w(32).clamp(28.0, 36.0),
            borderRadius: r.gap(8),
          ),
          SizedBox(width: r.gap(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LazyPlaceholder(
                  opacity: opacity,
                  color: dashboard.secondaryText,
                  height: r.sp(12).clamp(11.0, 13.0),
                  width: double.infinity,
                  borderRadius: r.gap(4),
                ),
                SizedBox(height: r.gap(6)),
                _LazyPlaceholder(
                  opacity: opacity,
                  color: dashboard.primaryText,
                  height: r.sp(15).clamp(14.0, 16.0),
                  width: r.w(72).clamp(60.0, 84.0),
                  borderRadius: r.gap(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LazyCompletedTripsList extends StatefulWidget {
  const _LazyCompletedTripsList();

  @override
  State<_LazyCompletedTripsList> createState() =>
      _LazyCompletedTripsListState();
}

class _LazyCompletedTripsListState extends State<_LazyCompletedTripsList>
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

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            r.gap(14),
            0,
            r.gap(14),
            r.gap(8),
          ),
          child: Column(
            children: List.generate(4, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: index == 3 ? 0 : r.gap(8)),
                child: _LazyTripRowPlaceholder(
                  opacity: opacity,
                  dashboard: dashboard,
                  r: r,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _LazyTripRowPlaceholder extends StatelessWidget {
  const _LazyTripRowPlaceholder({
    required this.opacity,
    required this.dashboard,
    required this.r,
  });

  final double opacity;
  final DashboardTheme dashboard;
  final AppResponsive r;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.gap(12)),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.circular(r.gap(12)),
      ),
      child: Row(
        children: [
          _LazyPlaceholder(
            opacity: opacity,
            color: dashboard.secondaryText,
            height: r.w(44).clamp(40.0, 48.0),
            width: r.w(44).clamp(40.0, 48.0),
            borderRadius: r.gap(10),
          ),
          SizedBox(width: r.gap(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LazyPlaceholder(
                  opacity: opacity,
                  color: dashboard.primaryText,
                  height: r.sp(16).clamp(15.0, 18.0),
                  width: double.infinity,
                  borderRadius: r.gap(4),
                ),
                SizedBox(height: r.gap(6)),
                _LazyPlaceholder(
                  opacity: opacity,
                  color: dashboard.secondaryText,
                  height: r.sp(13).clamp(12.0, 14.0),
                  width: r.w(100).clamp(84.0, 120.0),
                  borderRadius: r.gap(4),
                ),
              ],
            ),
          ),
          SizedBox(width: r.gap(12)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _LazyPlaceholder(
                opacity: opacity,
                color: const Color(0xFF049327),
                height: r.sp(16).clamp(15.0, 18.0),
                width: r.w(72).clamp(60.0, 84.0),
                borderRadius: r.gap(4),
              ),
              SizedBox(height: r.gap(6)),
              _LazyPlaceholder(
                opacity: opacity,
                color: dashboard.secondaryText,
                height: r.sp(13).clamp(12.0, 14.0),
                width: r.w(40).clamp(34.0, 48.0),
                borderRadius: r.gap(4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LazyPlaceholder extends StatelessWidget {
  const _LazyPlaceholder({
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
