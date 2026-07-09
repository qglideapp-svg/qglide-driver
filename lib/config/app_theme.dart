import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_constants.dart';
import 'app_fonts.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.loginButton,
    required this.socialButtonBackground,
    required this.authFieldFill,
    required this.authFieldBorder,
    required this.authFocusBorder,
    required this.mutedText,
    required this.iconMuted,
    required this.cardSurface,
    required this.infoSurface,
    required this.primaryAuthBackgroundAsset,
    required this.formAuthBackgroundAsset,
    required this.appleButtonBackground,
    required this.appleButtonForeground,
    required this.appleButtonBorder,
    required this.googleButtonBackground,
    required this.googleButtonForeground,
    required this.googleButtonBorder,
    required this.linkAccent,
    required this.primaryButtonForeground,
    required this.primaryButtonBorder,
  });

  final Color loginButton;
  final Color socialButtonBackground;
  final Color authFieldFill;
  final Color authFieldBorder;
  final Color authFocusBorder;
  final Color mutedText;
  final Color iconMuted;
  final Color cardSurface;
  final Color infoSurface;
  final String primaryAuthBackgroundAsset;
  final String formAuthBackgroundAsset;
  final Color appleButtonBackground;
  final Color appleButtonForeground;
  final Color appleButtonBorder;
  final Color googleButtonBackground;
  final Color googleButtonForeground;
  final Color googleButtonBorder;
  final Color linkAccent;
  final Color primaryButtonForeground;
  final Color primaryButtonBorder;

  static AppThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<AppThemeExtension>()!;
  }

  @override
  AppThemeExtension copyWith({
    Color? loginButton,
    Color? socialButtonBackground,
    Color? authFieldFill,
    Color? authFieldBorder,
    Color? authFocusBorder,
    Color? mutedText,
    Color? iconMuted,
    Color? cardSurface,
    Color? infoSurface,
    String? primaryAuthBackgroundAsset,
    String? formAuthBackgroundAsset,
    Color? appleButtonBackground,
    Color? appleButtonForeground,
    Color? appleButtonBorder,
    Color? googleButtonBackground,
    Color? googleButtonForeground,
    Color? googleButtonBorder,
    Color? linkAccent,
    Color? primaryButtonForeground,
    Color? primaryButtonBorder,
  }) {
    return AppThemeExtension(
      loginButton: loginButton ?? this.loginButton,
      socialButtonBackground: socialButtonBackground ?? this.socialButtonBackground,
      authFieldFill: authFieldFill ?? this.authFieldFill,
      authFieldBorder: authFieldBorder ?? this.authFieldBorder,
      authFocusBorder: authFocusBorder ?? this.authFocusBorder,
      mutedText: mutedText ?? this.mutedText,
      iconMuted: iconMuted ?? this.iconMuted,
      cardSurface: cardSurface ?? this.cardSurface,
      infoSurface: infoSurface ?? this.infoSurface,
      primaryAuthBackgroundAsset:
          primaryAuthBackgroundAsset ?? this.primaryAuthBackgroundAsset,
      formAuthBackgroundAsset:
          formAuthBackgroundAsset ?? this.formAuthBackgroundAsset,
      appleButtonBackground:
          appleButtonBackground ?? this.appleButtonBackground,
      appleButtonForeground:
          appleButtonForeground ?? this.appleButtonForeground,
      appleButtonBorder: appleButtonBorder ?? this.appleButtonBorder,
      googleButtonBackground:
          googleButtonBackground ?? this.googleButtonBackground,
      googleButtonForeground:
          googleButtonForeground ?? this.googleButtonForeground,
      googleButtonBorder: googleButtonBorder ?? this.googleButtonBorder,
      linkAccent: linkAccent ?? this.linkAccent,
      primaryButtonForeground:
          primaryButtonForeground ?? this.primaryButtonForeground,
      primaryButtonBorder: primaryButtonBorder ?? this.primaryButtonBorder,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other == null) return this;
    return AppThemeExtension(
      loginButton: Color.lerp(loginButton, other.loginButton, t)!,
      socialButtonBackground:
          Color.lerp(socialButtonBackground, other.socialButtonBackground, t)!,
      authFieldFill: Color.lerp(authFieldFill, other.authFieldFill, t)!,
      authFieldBorder: Color.lerp(authFieldBorder, other.authFieldBorder, t)!,
      authFocusBorder: Color.lerp(authFocusBorder, other.authFocusBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      primaryAuthBackgroundAsset: t < 0.5
          ? primaryAuthBackgroundAsset
          : other.primaryAuthBackgroundAsset,
      formAuthBackgroundAsset:
          t < 0.5 ? formAuthBackgroundAsset : other.formAuthBackgroundAsset,
      appleButtonBackground:
          Color.lerp(appleButtonBackground, other.appleButtonBackground, t)!,
      appleButtonForeground:
          Color.lerp(appleButtonForeground, other.appleButtonForeground, t)!,
      appleButtonBorder:
          Color.lerp(appleButtonBorder, other.appleButtonBorder, t)!,
      googleButtonBackground:
          Color.lerp(googleButtonBackground, other.googleButtonBackground, t)!,
      googleButtonForeground:
          Color.lerp(googleButtonForeground, other.googleButtonForeground, t)!,
      googleButtonBorder:
          Color.lerp(googleButtonBorder, other.googleButtonBorder, t)!,
      linkAccent: Color.lerp(linkAccent, other.linkAccent, t)!,
      primaryButtonForeground:
          Color.lerp(primaryButtonForeground, other.primaryButtonForeground, t)!,
      primaryButtonBorder:
          Color.lerp(primaryButtonBorder, other.primaryButtonBorder, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static const _lightExtension = AppThemeExtension(
    loginButton: AppColors.loginButton,
    socialButtonBackground: AppColors.socialButtonBackground,
    authFieldFill: Colors.white,
    authFieldBorder: Colors.black,
    authFocusBorder: AppColors.accentYellowSolid,
    mutedText: Color(0xB8000000),
    iconMuted: Color(0x73000000),
    cardSurface: Color(0xD9FFFFFF),
    infoSurface: AppColors.socialButtonBackground,
    primaryAuthBackgroundAsset: AppConstants.loginBackgroundAsset,
    formAuthBackgroundAsset: AppConstants.signupBackgroundAsset,
    appleButtonBackground: Colors.white,
    appleButtonForeground: Colors.black,
    appleButtonBorder: Colors.black,
    googleButtonBackground: Colors.black,
    googleButtonForeground: Colors.white,
    googleButtonBorder: Colors.white,
    linkAccent: AppColors.loginButton,
    primaryButtonForeground: Colors.black,
    primaryButtonBorder: Colors.black,
  );

  static const _darkExtension = AppThemeExtension(
    loginButton: AppColors.loginButton,
    socialButtonBackground: Color(0xFF1F1F1F),
    authFieldFill: Color(0xFF121212),
    authFieldBorder: Colors.white,
    authFocusBorder: AppColors.loginButton,
    mutedText: Color(0xB3FFFFFF),
    iconMuted: Color(0x8CFFFFFF),
    cardSurface: Color(0xCC1A1A1A),
    infoSurface: Color(0xFF1F1F1F),
    primaryAuthBackgroundAsset: AppConstants.darkAuthBackgroundAsset,
    formAuthBackgroundAsset: AppConstants.darkAuthBackgroundAsset,
    appleButtonBackground: Colors.black,
    appleButtonForeground: Colors.white,
    appleButtonBorder: Colors.white,
    googleButtonBackground: Colors.white,
    googleButtonForeground: Colors.black,
    googleButtonBorder: Colors.white,
    linkAccent: AppColors.loginButton,
    primaryButtonForeground: Colors.black,
    primaryButtonBorder: Colors.black,
  );

  static ThemeData get light => _build(Brightness.light, _lightExtension);

  static ThemeData get dark => _build(Brightness.dark, _darkExtension);

  static ThemeData _build(
    Brightness brightness,
    AppThemeExtension extension,
  ) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? Colors.black : Colors.white;
    final onSurface = isDark ? Colors.white : Colors.black;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: surface,
      fontFamily: AppFonts.plusJakartaSans,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.loginButton,
        onPrimary: Colors.black,
        secondary: AppColors.accentYellowSolid,
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      extensions: [extension],
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeExtension get appTheme => AppThemeExtension.of(this);
}
