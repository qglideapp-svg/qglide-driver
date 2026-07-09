import 'package:flutter/material.dart';

import 'app_fonts.dart';

/// Responsive helpers based on a 390 x 844 design canvas (iPhone 14 class).
class AppResponsive {
  AppResponsive(this.context);

  final BuildContext context;

  static const designWidth = 390.0;
  static const designHeight = 844.0;

  static AppResponsive of(BuildContext context) => AppResponsive(context);

  Size get size => MediaQuery.sizeOf(context);
  double get width => size.width;
  double get height => size.height;
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(context);

  bool get isCompact => width < 360;
  bool get isTablet => width >= 600;
  bool get isLargeTablet => width >= 900;

  double get _widthScale => (width / designWidth).clamp(0.82, 1.35);
  double get _heightScale => (height / designHeight).clamp(0.82, 1.25);

  double w(double value) => value * _widthScale;
  double h(double value) => value * _heightScale;
  double sp(double value) => value * _widthScale;

  double get maxContentWidth {
    if (isLargeTablet) return 560;
    if (isTablet) return 520;
    return width;
  }

  EdgeInsets get contentPadding => EdgeInsets.fromLTRB(
        w(isTablet ? 32 : 24),
        h(24),
        w(isTablet ? 32 : 24),
        h(32),
      );

  EdgeInsets get signupTopPadding => EdgeInsets.fromLTRB(
        w(isTablet ? 32 : 24),
        h(54),
        w(isTablet ? 32 : 24),
        h(32),
      );

  double gap(double value) => w(value);

  double get ridePanelHorizontalInset => gap(isTablet ? 24 : 16);

  double _fitPanelHeight({
    required double design,
    required double min,
    required double max,
    required double heightFraction,
  }) {
    final byDesign = design.clamp(min, max);
    final available = (height - viewPadding.top - h(64)) * heightFraction;
    if (isCompact || height < 720) {
      return byDesign.clamp(min * 0.82, available);
    }
    return byDesign.clamp(min, max).clamp(0, available);
  }

  double rideDashboardPanelHeight({
    bool activeTrip = false,
    bool activeRide = false,
    bool earningsTab = false,
  }) {
    if (activeTrip) {
      return _fitPanelHeight(
        design: h(560),
        min: 380,
        max: 620,
        heightFraction: 0.68,
      );
    }
    if (activeRide) {
      return _fitPanelHeight(
        design: h(420),
        min: 320,
        max: 480,
        heightFraction: 0.54,
      );
    }
    if (earningsTab) {
      return earningsPanelHeight();
    }
    return defaultDashboardPanelHeight();
  }

  double rideCompletedModalHeight() {
    final badgeScale = isCompact ? 0.82 : 0.88;
    final baseBadge =
        w(isCompact ? 128 : 146).clamp(108.0, 180.0) * badgeScale;
    final badgeSize = baseBadge.clamp(88.0, 180.0);
    final badgeCanvas = badgeSize * (badgeScale < 1 ? 1.4 : 1.55);
    final shellPadding = gap(isCompact ? 28 : 36);
    final textBlock = h(30) + h(12) + h(46);
    final buttons = h(48);
    final gaps = gap(isCompact ? 36 : 46);
    final contentHeight =
        badgeCanvas + shellPadding + textBlock + buttons + gaps + h(8);
    final maxAvailable = height -
        viewPadding.top -
        h(72) -
        viewPadding.bottom -
        ridePanelHorizontalInset;
    return contentHeight.clamp(320, maxAvailable);
  }

  double rideModalMaxHeight({
    bool rideCompleted = false,
    bool activePickup = false,
  }) {
    if (rideCompleted) {
      return rideCompletedModalHeight();
    }
    if (activePickup) {
      return _fitPanelHeight(
        design: h(520),
        min: 400,
        max: 580,
        heightFraction: 0.72,
      );
    }
    return _fitPanelHeight(
      design: h(460),
      min: 360,
      max: 520,
      heightFraction: 0.64,
    );
  }

  double goOnlineNotchTop({bool activeTrip = false}) =>
      activeTrip ? -h(10) : -h(18);

  double dashboardNotchClearance() => h(38);

  double earningsPanelHeight() {
    final topClearance = viewPadding.top + h(52);
    final available = height - topClearance;
    return available.clamp(h(280), height);
  }

  /// Original short dashboard height — used to anchor the map location button.
  double defaultDashboardPanelHeight() {
    return _fitPanelHeight(
      design: h(372),
      min: 280,
      max: 430,
      heightFraction: 0.48,
    );
  }

  double locationButtonBottomOffset({
    required bool showsBottomModal,
    required double modalHeightEstimate,
    required double modalBottomInset,
    required double activePanelHeight,
    required bool isDefaultDashboard,
  }) {
    final lift = h(24);
    if (showsBottomModal) {
      return modalHeightEstimate + modalBottomInset + lift;
    }
    if (isDefaultDashboard) {
      return defaultDashboardPanelHeight() + h(52) + lift;
    }
    return activePanelHeight + h(52) + lift;
  }

  double tripProfileTopOffset() => isCompact ? gap(28) : gap(40);

  double get logoHeight => w(48).clamp(40.0, 56.0);
  double get iconSm => w(20).clamp(18.0, 24.0);
  double get iconMd => w(22).clamp(20.0, 26.0);
  double get borderRadiusMd => w(14).clamp(12.0, 18.0);
  double get borderRadiusLg => w(32).clamp(24.0, 36.0);

  double get titleSize => sp(28).clamp(22.0, 34.0);
  double get headlineSize => sp(48).clamp(30.0, 52.0);
  double get subtitleSize => sp(16).clamp(14.0, 19.0);
  double get bodySize => sp(15).clamp(13.0, 17.0);
  double get captionSize => sp(13).clamp(11.0, 15.0);
  double get buttonTextSize => sp(20).clamp(17.0, 22.0);

  /// Reserved bottom space on compact phones so copy clears the footer controls.
  double get onboardingFooterHeight => h(148).clamp(132.0, 160.0);

  double otpBoxSize(double horizontalPadding) {
    final available = width - (horizontalPadding * 2);
    final spacing = gap(8) * 5;
    return ((available - spacing) / 6).clamp(36.0, 52.0);
  }

  TextStyle titleStyle({Color color = Colors.black}) => TextStyle(
        fontFamily: AppFonts.plusJakartaSans,
        fontSize: titleSize,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
      );

  TextStyle subtitleStyle({Color? color}) => TextStyle(
        fontFamily: AppFonts.plusJakartaSans,
        fontSize: subtitleSize,
        fontWeight: FontWeight.w400,
        color: color ?? Colors.black.withValues(alpha: 0.72),
        height: 1.45,
      );

  TextStyle bodyStyle({Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: AppFonts.plusJakartaSans,
        fontSize: bodySize,
        fontWeight: weight,
        color: color ?? Colors.black.withValues(alpha: 0.75),
      );

  TextStyle captionStyle({Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: AppFonts.plusJakartaSans,
        fontSize: captionSize,
        fontWeight: weight,
        color: color ?? Colors.black.withValues(alpha: 0.65),
        height: 1.4,
      );
}

extension ResponsiveBuildContext on BuildContext {
  AppResponsive get responsive => AppResponsive.of(this);
}
