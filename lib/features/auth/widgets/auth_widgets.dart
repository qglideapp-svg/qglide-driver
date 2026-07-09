import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../config/app_constants.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/app_strings.dart';
import '../../../config/app_theme.dart';
import '../../../shared/widgets/app_strings_scope.dart';

String formatDriverPhoneDisplay(
  String phone, {
  String countryCode = '+974',
}) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return countryCode;

  final codeDigits = countryCode.replaceAll(RegExp(r'\D'), '');
  var local = digits;
  if (codeDigits.isNotEmpty &&
      local.startsWith(codeDigits) &&
      local.length > codeDigits.length) {
    local = local.substring(codeDigits.length);
  }
  if (local.length >= 8) {
    return '$countryCode ${local.substring(0, 4)} ${local.substring(4)}';
  }
  if (local.isEmpty || local == codeDigits) return countryCode;
  return '$countryCode $local';
}

class PhonePrefix extends StatelessWidget {
  const PhonePrefix({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final flagSize = r.w(22).clamp(20.0, 26.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: flagSize,
          height: flagSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.authFieldBorder.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            AppConstants.qatarFlagAsset,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: r.gap(8)),
        Text(
          '+974',
          style: TextStyle(
            fontFamily: AppFonts.plusJakartaSans,
            fontSize: r.sp(15),
            fontWeight: FontWeight.w500,
            color: onSurface.withValues(alpha: 0.85),
          ),
        ),
        Container(
          width: 1,
          height: flagSize,
          margin: EdgeInsets.symmetric(horizontal: r.gap(10)),
          color: theme.authFieldBorder.withValues(alpha: 0.2),
        ),
        Icon(
          Icons.phone_outlined,
          size: r.iconSm,
          color: theme.iconMuted,
        ),
        SizedBox(width: r.gap(8)),
      ],
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.prefix,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final Widget? prefix;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final radius = r.borderRadiusMd;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      style: TextStyle(
        fontFamily: AppFonts.plusJakartaSans,
        fontSize: r.bodySize,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontFamily: AppFonts.plusJakartaSans,
          fontSize: r.bodySize,
          fontWeight: FontWeight.w400,
          color: theme.iconMuted,
        ),
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: EdgeInsets.only(left: r.gap(16), right: r.gap(4)),
                child: prefix,
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        filled: true,
        fillColor: theme.authFieldFill,
        contentPadding: EdgeInsets.symmetric(
          horizontal: r.gap(16),
          vertical: r.h(18),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: theme.authFieldBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: theme.authFocusBorder, width: 1.5),
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: theme.loginButton,
          foregroundColor: theme.primaryButtonForeground,
          surfaceTintColor: Colors.transparent,
          side: BorderSide(color: theme.primaryButtonBorder, width: 1),
          padding: EdgeInsets.symmetric(vertical: r.h(18)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.borderRadiusLg),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.plusJakartaSans,
            fontSize: r.buttonTextSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.onPressed,
    this.borderColor,
    this.expanded = true,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        surfaceTintColor: Colors.transparent,
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!, width: 1),
        padding: EdgeInsets.symmetric(vertical: r.h(16)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.borderRadiusMd),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: r.gap(10)),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.plusJakartaSans,
                fontSize: r.bodySize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class AuthAppleButton extends StatelessWidget {
  const AuthAppleButton({super.key, this.onPressed, this.expanded = true});

  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
    final theme = context.appTheme;
    final r = context.responsive;

    return AuthSocialButton(
      label: expanded ? s.continueWithApple : s.apple,
      backgroundColor: theme.appleButtonBackground,
      foregroundColor: theme.appleButtonForeground,
      borderColor: theme.appleButtonBorder,
      icon: Icon(Icons.apple, size: r.iconMd),
      onPressed: onPressed ?? () {},
      expanded: expanded,
    );
  }
}

class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({super.key, this.onPressed, this.expanded = true});

  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
    final theme = context.appTheme;
    final r = context.responsive;

    return AuthSocialButton(
      label: expanded ? s.continueWithGoogle : s.google,
      backgroundColor: theme.googleButtonBackground,
      foregroundColor: theme.googleButtonForeground,
      borderColor: theme.googleButtonBorder,
      icon: GoogleLogoIcon(size: expanded ? null : r.iconSm),
      onPressed: onPressed,
      expanded: expanded,
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final theme = context.appTheme;

    return Row(
      children: [
        Expanded(
          child: Divider(color: theme.authFieldBorder.withValues(alpha: 0.15)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.gap(16)),
          child: Text(
            s.orDivider,
            style: TextStyle(
              fontFamily: AppFonts.plusJakartaSans,
              fontSize: r.captionSize,
              fontWeight: FontWeight.w500,
              color: theme.iconMuted,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: theme.authFieldBorder.withValues(alpha: 0.15)),
        ),
      ],
    );
  }
}

class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? context.responsive.iconMd;
    return SizedBox(
      width: resolvedSize,
      height: resolvedSize,
      child: SvgPicture.asset(
        AppConstants.googleLogoAsset,
        width: resolvedSize,
        height: resolvedSize,
        fit: BoxFit.contain,
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final logoHeight = height ?? r.logoHeight;

    return Image.asset(
      AppConstants.logoAsset,
      height: logoHeight,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}
