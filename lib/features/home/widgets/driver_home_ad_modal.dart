import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../models/ad_placement_payload.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';

class DriverHomeAdModal extends StatelessWidget {
  const DriverHomeAdModal({super.key, required this.placement});

  final AdPlacementPayload placement;

  static Future<void> show(
    BuildContext context, {
    required AdPlacementPayload placement,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => DriverHomeAdModal(placement: placement),
    );
  }

  Future<void> _onCtaTap(BuildContext context) async {
    final link = placement.resolveLinkForPlatform();
    if (link.isEmpty) return;

    final uri = Uri.tryParse(link);
    if (uri != null) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && uri.scheme != 'http' && uri.scheme != 'https') {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } catch (_) {}
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  void _dismiss(BuildContext context) => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final hasImage = placement.creativeImageUrl.isNotEmpty;
    final imageHeight = r.h(180).clamp(150.0, 220.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: r.gap(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.gap(24)),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(r.borderRadiusMd),
                child: SizedBox(
                  width: double.infinity,
                  height: imageHeight,
                  child: hasImage
                      ? Image.network(
                          placement.creativeImageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const _AdCreativeFallback();
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const _AdCreativeFallback(),
                        )
                      : Image.asset(
                          AppConstants.dashboardPromoIllustrationAsset,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              ResponsiveGap(r.isCompact ? 16 : 20),
              if (placement.supportingCopy.isNotEmpty) ...[
                Text(
                  placement.supportingCopy,
                  textAlign: TextAlign.center,
                  textDirection: s.textDirection,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(13).clamp(12.0, 14.0),
                    color: dashboard.secondaryText,
                    height: 1.4,
                  ),
                ),
                ResponsiveGap(r.isCompact ? 8 : 10),
              ],
              Text(
                placement.headline,
                textAlign: TextAlign.center,
                textDirection: s.textDirection,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(22).clamp(20.0, 26.0),
                  fontWeight: FontWeight.w700,
                  color: dashboard.primaryText,
                  height: 1.25,
                ),
              ),
              ResponsiveGap(r.isCompact ? 20 : 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _onCtaTap(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.loginButton,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: r.gap(14)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.borderRadiusMd),
                    ),
                  ),
                  child: Text(
                    placement.buttonLabel,
                    textDirection: s.textDirection,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(16).clamp(15.0, 18.0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ResponsiveGap(12),
              SizedBox(
                width: double.infinity,
                child: _ModalActionButton(
                  label: s.cancel,
                  backgroundColor: dashboard.cancelButtonBg,
                  textColor: dashboard.secondaryText,
                  onPressed: () => _dismiss(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalActionButton extends StatelessWidget {
  const _ModalActionButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(r.gap(10)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(r.gap(10)),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.h(14)),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(15).clamp(14.0, 17.0),
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdCreativeFallback extends StatelessWidget {
  const _AdCreativeFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E56B5),
            Color(0xFF3B8FE8),
            Color(0xFFE6C35C),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'QGlide',
        style: TextStyle(
          fontFamily: AppFonts.satoshi,
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: context.responsive.sp(16).clamp(14.0, 18.0),
        ),
      ),
    );
  }
}
