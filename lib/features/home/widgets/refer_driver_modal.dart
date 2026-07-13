import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../../../shared/widgets/ride_panel_shared.dart';
import '../refer_driver_progress_args.dart';

class ReferDriverShare {
  static String get _storeUrl {
    if (!kIsWeb && Platform.isIOS) {
      return AppConstants.iosAppStoreUrl;
    }
    return AppConstants.androidPlayStoreUrl;
  }

  static Future<void> copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    final strings = AppStringsScope.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.referDriverCodeCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Future<void> shareCode(
    BuildContext context,
    String code, {
    Rect? sharePositionOrigin,
  }) async {
    final strings = AppStringsScope.of(context);
    await SharePlus.instance.share(
      ShareParams(
        text: strings.referDriverShareMessage(code, storeUrl: _storeUrl),
        subject: strings.referDriverTitle,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

class ReferDriverModal extends StatelessWidget {
  const ReferDriverModal({
    super.key,
    required this.referralCode,
  });

  final String referralCode;

  static Future<void> show(
    BuildContext context, {
    required String referralCode,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => ReferDriverModal(referralCode: referralCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final code = referralCode.trim();

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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: r.gap(24),
                    offset: Offset(0, r.gap(8)),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: r.w(56).clamp(48.0, 64.0),
                    height: r.w(56).clamp(48.0, 64.0),
                    decoration: BoxDecoration(
                      color: AppColors.loginButton.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      color: AppColors.loginButton,
                      size: r.iconMd,
                    ),
                  ),
                  ResponsiveGap(16),
                  Text(
                    s.referDriverTitle,
                    textAlign: TextAlign.center,
                    textDirection: s.textDirection,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(22).clamp(20.0, 24.0),
                      fontWeight: FontWeight.w700,
                      color: dashboard.primaryText,
                    ),
                  ),
                  ResponsiveGap(8),
                  Text(
                    s.referDriverSubtitle,
                    textAlign: TextAlign.center,
                    textDirection: s.textDirection,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(15).clamp(14.0, 16.0),
                      color: dashboard.bodyText,
                      height: 1.45,
                    ),
                  ),
                  ResponsiveGap(20),
                  Container(
                    width: double.infinity,
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
                            textAlign: TextAlign.center,
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
                          onPressed: () => ReferDriverShare.copyCode(context, code),
                          icon: Icon(
                            Icons.copy_rounded,
                            color: dashboard.secondaryText,
                            size: r.sp(20).clamp(18.0, 22.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ResponsiveGap(20),
                  RideActionButton(
                    label: s.referDriverViewProgress,
                    color: dashboard.cancelButtonBg,
                    textColor: dashboard.primaryText,
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(
                        AppRoutes.referDriverProgress,
                        arguments: ReferDriverProgressArgs(
                          initialReferralCode: code,
                        ),
                      );
                    },
                  ),
                  ResponsiveGap(12),
                  Builder(
                    builder: (buttonContext) {
                      return RideActionButton(
                        label: s.referDriverShare,
                        color: AppColors.loginButton,
                        onPressed: () {
                          final box =
                              buttonContext.findRenderObject() as RenderBox?;
                          final origin = box != null
                              ? box.localToGlobal(Offset.zero) & box.size
                              : null;
                          unawaited(
                            ReferDriverShare.shareCode(
                              context,
                              code,
                              sharePositionOrigin: origin,
                            ),
                          );
                        },
                      );
                    },
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
