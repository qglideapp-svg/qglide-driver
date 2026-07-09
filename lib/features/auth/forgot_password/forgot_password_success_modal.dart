import 'package:flutter/material.dart';

import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/app_theme.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordSuccessModal extends StatelessWidget {
  const ForgotPasswordSuccessModal({
    super.key,
    required this.email,
    required this.onBackToLogin,
  });

  final String email;
  final VoidCallback onBackToLogin;

  static Future<void> show(
    BuildContext context, {
    required String email,
    required VoidCallback onBackToLogin,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => ForgotPasswordSuccessModal(
        email: email,
        onBackToLogin: onBackToLogin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final iconSize = r.w(56).clamp(48.0, 64.0);

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
                  Icons.mark_email_read_outlined,
                  size: r.iconMd,
                  color: theme.linkAccent,
                ),
              ),
              ResponsiveGap(20),
              Text(
                'Password reset sent',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(22).clamp(20.0, 24.0),
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              ResponsiveGap(12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: r.subtitleStyle(color: theme.mutedText),
                  children: [
                    const TextSpan(
                      text: 'A password reset link has been sent to ',
                    ),
                    TextSpan(
                      text: email,
                      style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text: '. Check your inbox and follow the link to reset your password.',
                    ),
                  ],
                ),
              ),
              ResponsiveGap(28),
              AuthPrimaryButton(
                label: 'Back to Login',
                onPressed: onBackToLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
