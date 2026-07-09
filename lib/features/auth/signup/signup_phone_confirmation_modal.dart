import 'package:flutter/material.dart';

import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/app_theme.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../widgets/auth_widgets.dart';

class SignupPhoneConfirmationModal extends StatelessWidget {
  const SignupPhoneConfirmationModal({
    super.key,
    required this.phoneNumber,
  });

  final String phoneNumber;

  static Future<bool> show(
    BuildContext context, {
    required String phoneNumber,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => SignupPhoneConfirmationModal(
        phoneNumber: phoneNumber,
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final iconSize = r.w(56).clamp(48.0, 64.0);
    final formattedPhone = formatDriverPhoneDisplay(phoneNumber);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: r.gap(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            r.gap(24),
            r.gap(32),
            r.gap(24),
            r.gap(24),
          ),
          decoration: BoxDecoration(
            color: theme.cardSurface,
            borderRadius: BorderRadius.circular(r.borderRadiusLg),
            border: Border.all(color: theme.authFieldBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: theme.infoSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phone_android_rounded,
                  size: r.iconMd,
                  color: theme.linkAccent,
                ),
              ),
              ResponsiveGap(20),
              Text(
                s.signupConfirmPhoneTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(22).clamp(20.0, 24.0),
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              ResponsiveGap(12),
              Text(
                formattedPhone,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.plusJakartaSans,
                  fontSize: r.sp(20).clamp(18.0, 22.0),
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  letterSpacing: 0.4,
                ),
              ),
              ResponsiveGap(12),
              Text(
                s.signupConfirmPhoneMessage,
                textAlign: TextAlign.center,
                style: r.subtitleStyle(color: theme.mutedText),
              ),
              ResponsiveGap(28),
              AuthPrimaryButton(
                label: s.proceed,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              ResponsiveGap(12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  s.cancel,
                  style: TextStyle(
                    fontFamily: AppFonts.plusJakartaSans,
                    fontSize: r.bodySize,
                    fontWeight: FontWeight.w600,
                    color: theme.mutedText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
