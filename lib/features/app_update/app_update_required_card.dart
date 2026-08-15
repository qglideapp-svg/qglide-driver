import 'package:flutter/material.dart';

import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../config/app_theme.dart';
import '../../features/auth/widgets/auth_widgets.dart';
import '../../models/ad_placement_payload.dart';
import '../../services/app_update_service.dart';
import '../../shared/widgets/app_strings_scope.dart';
import '../../shared/widgets/responsive_screen_shell.dart';

class AppUpdateRequiredCard extends StatelessWidget {
  const AppUpdateRequiredCard({
    super.key,
    required this.placement,
    required this.onUpdate,
  });

  final AdPlacementPayload placement;
  final Future<void> Function() onUpdate;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final iconSize = r.w(56).clamp(48.0, 64.0);
    final hasImage = placement.creativeImageUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.gap(24)),
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
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(r.borderRadiusMd),
                    child: Image.network(
                      placement.creativeImageUrl,
                      width: double.infinity,
                      height: r.h(160).clamp(120.0, 180.0),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _UpdateIcon(
                        iconSize: iconSize,
                        theme: theme,
                        r: r,
                      ),
                    ),
                  ),
                  ResponsiveGap(20),
                ] else ...[
                  _UpdateIcon(iconSize: iconSize, theme: theme, r: r),
                  ResponsiveGap(20),
                ],
                Text(
                  AppUpdateService.localizedTitle(s),
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
                  AppUpdateService.localizedMessage(s),
                  textAlign: TextAlign.center,
                  style: r.subtitleStyle(color: theme.mutedText),
                ),
                ResponsiveGap(28),
                AuthPrimaryButton(
                  label: AppUpdateService.localizedButtonLabel(s),
                  onPressed: () => onUpdate(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateIcon extends StatelessWidget {
  const _UpdateIcon({
    required this.iconSize,
    required this.theme,
    required this.r,
  });

  final double iconSize;
  final AppThemeExtension theme;
  final AppResponsive r;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: theme.infoSurface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.system_update_alt_rounded,
        size: r.iconMd,
        color: theme.linkAccent,
      ),
    );
  }
}
