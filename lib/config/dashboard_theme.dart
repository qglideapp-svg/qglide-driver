import 'package:flutter/material.dart';

import 'app_colors.dart';

class DashboardTheme {
  const DashboardTheme._(this.brightness);

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  factory DashboardTheme.of(BuildContext context) {
    return DashboardTheme._(Theme.of(context).brightness);
  }

  Color get scaffold => isDark ? Colors.black : Colors.white;

  Color get screenBackground =>
      isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF4F4F4);

  Color get panelFill => isDark ? const Color(0xFF141010) : Colors.white;

  Color get card => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3);

  Color get surface => isDark ? const Color(0xFF1A1A1A) : Colors.white;

  Color get primaryText => isDark ? Colors.white : Colors.black;

  Color get secondaryText =>
      isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black45;

  Color get mutedText =>
      isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black54;

  Color get bodyText =>
      isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.85);

  Color get headerPill => isDark ? const Color(0xFF2A2A2A) : Colors.white;

  Color get headerPillText =>
      isDark ? Colors.white : Colors.black.withValues(alpha: 0.8);

  Color get iconButton => isDark ? const Color(0xFF2A2A2A) : Colors.white;

  Color get notificationIcon =>
      isDark ? AppColors.loginButton : Colors.black.withValues(alpha: 0.55);

  Color get inactiveTab =>
      isDark ? Colors.white.withValues(alpha: 0.38) : Colors.black38;

  Color get mapFallback =>
      isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF4F1EC);

  Color get walletCard => isDark ? const Color(0xFF2A2A2A) : Colors.white;

  Color get walletCardBorder =>
      isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEFEFEF);

  Color get completedTripsBg => isDark ? const Color(0xFF1E1E1E) : Colors.white;

  Color get inputFill =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

  Color get statValue =>
      isDark ? Colors.white : Colors.black.withValues(alpha: 0.82);

  Color get locationButton => isDark ? const Color(0xFF2A2A2A) : Colors.white;

  Color get iconBox => card;

  Color get pillBackground =>
      isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF1F1F1);

  Color get divider =>
      isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0);

  Color get chevron =>
      isDark ? const Color(0xFF666666) : const Color(0xFFB0B0B0);

  Color get borderSubtle =>
      isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE8E8E8);

  Color get toggleTrack =>
      isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE4E4E4);

  Color get toggleBorder =>
      isDark ? const Color(0xFF4A4A4A) : const Color(0xFFD6D6D6);

  Color get toggleThumbOff => isDark ? const Color(0xFF555555) : Colors.white;

  Color get embossedHighlight =>
      isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.85);

  Color get embossedShadow =>
      isDark ? Colors.black.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.08);

  Color get panelShadow =>
      isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.12);

  Color get cancelButtonBg =>
      isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF1F1F1);

  Color get chatBubbleIncoming => inputFill;

  Color get onPrimaryButton => Colors.white;

  List<Color> get earningsGradient => isDark
      ? const [
          Color(0xFF141010),
          Color(0xFF1F1A12),
          Color(0xFF2A2418),
        ]
      : const [
          Colors.white,
          Color(0xFFFDF8EC),
          AppColors.earningsGradient,
        ];

  Widget panelImage(String asset, {BoxFit fit = BoxFit.fill}) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(panelFill, BlendMode.srcIn),
      child: Image.asset(asset, fit: fit),
    );
  }

  static const darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d1d1d"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1d1d1d"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#e0e0e0"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#c7c7c7"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d0d0d0"}]},
  {"featureType":"poi.business","elementType":"labels.text.fill","stylers":[{"color":"#e6e6e6"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1f2a1f"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#b8c9b8"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#f0f0f0"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d6d6d6"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0f1419"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#8aa4b8"}]}
]
''';
}
