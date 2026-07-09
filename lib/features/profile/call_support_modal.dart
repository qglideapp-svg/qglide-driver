import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../config/dashboard_theme.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../services/phone_dialer_service.dart';
import '../../shared/widgets/app_strings_scope.dart';
import '../../shared/widgets/responsive_screen_shell.dart';
import '../../shared/widgets/ride_panel_shared.dart';

class CallSupportModal extends StatelessWidget {
  const CallSupportModal({
    super.key,
    this.phoneNumber = AppConstants.supportPhoneNumber,
    this.onDialNow,
  });

  final String phoneNumber;
  final VoidCallback? onDialNow;

  static Future<void> show(
    BuildContext context, {
    String phoneNumber = AppConstants.supportPhoneNumber,
    VoidCallback? onDialNow,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => CallSupportModal(
        phoneNumber: phoneNumber,
        onDialNow: onDialNow,
      ),
    );
  }

  Future<void> _handleDial(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    if (onDialNow != null) {
      onDialNow!();
      return;
    }

    final error = await PhoneDialerService.launch(phoneNumber);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: r.gap(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                r.gap(24),
                r.gap(36),
                r.gap(24),
                r.gap(24),
              ),
              decoration: BoxDecoration(
                color: dashboard.surface,
                borderRadius: BorderRadius.circular(r.borderRadiusLg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.dialSupportPhone(phoneNumber),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(22).clamp(20.0, 24.0),
                      fontWeight: FontWeight.w700,
                      color: dashboard.primaryText,
                    ),
                  ),
                  ResponsiveGap(12),
                  Text(
                    s.callSupportModalMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(16).clamp(15.0, 18.0),
                      color: dashboard.bodyText,
                      height: 1.45,
                    ),
                  ),
                  ResponsiveGap(24),
                  RideActionButton(
                    label: s.dialNow,
                    color: AppColors.loginButton,
                    onPressed: () => unawaited(_handleDial(context)),
                  ),
                  ResponsiveGap(12),
                  RideActionButton(
                    label: s.cancel,
                    color: dashboard.cancelButtonBg,
                    textColor: dashboard.secondaryText,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Positioned(
              top: r.gap(12),
              right: r.gap(12),
              child: _CloseButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final size = r.w(32).clamp(28.0, 36.0);

    return Material(
      color: dashboard.iconBox,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.close_rounded,
            size: r.iconSm,
            color: dashboard.secondaryText,
          ),
        ),
      ),
    );
  }
}
