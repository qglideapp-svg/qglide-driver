import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../models/ad_placement_payload.dart';
import '../../../services/ad_placement_service.dart';
import '../../../shared/widgets/app_strings_scope.dart';

class DriverAdPlacementBanner extends StatelessWidget {
  const DriverAdPlacementBanner({
    super.key,
    this.placementKey = AdPlacementCache.driverAccountBannerKey,
    this.showSkeletonUntilLoaded = true,
  });

  final String placementKey;
  final bool showSkeletonUntilLoaded;

  Future<void> _onCtaTap(BuildContext context, AdPlacementPayload placement) async {
    final link = placement.deepLink.trim();
    if (link.isEmpty) return;

    final uri = Uri.tryParse(link);
    if (uri == null) return;

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdPlacementCache.instance,
      builder: (context, _) {
        final cache = AdPlacementCache.instance;
        if (!cache.hasLoaded(placementKey)) {
          return showSkeletonUntilLoaded
              ? const _AdPlacementSkeleton()
              : const SizedBox.shrink();
        }

        final placement = cache.get(placementKey);
        if (placement == null) {
          return const _AdPlacementFallbackCard();
        }

        return _AdPlacementCard(
          placement: placement,
          onCtaTap: () => _onCtaTap(context, placement),
        );
      },
    );
  }
}

class _AdPlacementCard extends StatelessWidget {
  const _AdPlacementCard({
    required this.placement,
    required this.onCtaTap,
  });

  final AdPlacementPayload placement;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);
    final creativeSize = r.w(104).clamp(88.0, 112.0);
    final hasImage = placement.creativeImageUrl.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(r.gap(12)),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(r.gap(10)),
            child: SizedBox(
              width: creativeSize,
              height: r.h(96).clamp(84.0, 104.0),
              child: hasImage
                  ? Image.network(
                      placement.creativeImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return _CreativeFallback(size: creativeSize);
                      },
                      errorBuilder: (_, __, ___) =>
                          _CreativeFallback(size: creativeSize),
                    )
                  : Image.asset(
                      AppConstants.dashboardPromoIllustrationAsset,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
          SizedBox(width: r.gap(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (placement.supportingCopy.isNotEmpty) ...[
                  Text(
                    placement.supportingCopy,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: s.textDirection,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(11).clamp(10.0, 12.0),
                      color: dashboard.secondaryText,
                    ),
                  ),
                  SizedBox(height: r.gap(4)),
                ],
                Text(
                  placement.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: s.textDirection,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(15).clamp(13.0, 17.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: r.gap(10)),
                Material(
                  color: AppColors.loginButton,
                  borderRadius: BorderRadius.circular(r.gap(8)),
                  child: InkWell(
                    onTap: onCtaTap,
                    borderRadius: BorderRadius.circular(r.gap(8)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.gap(14),
                        vertical: r.gap(6),
                      ),
                      child: Text(
                        placement.buttonLabel,
                        textDirection: s.textDirection,
                        style: TextStyle(
                          fontFamily: AppFonts.satoshi,
                          fontSize: r.sp(11).clamp(10.0, 12.0),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreativeFallback extends StatelessWidget {
  const _CreativeFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
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
          fontSize: context.responsive.sp(11).clamp(10.0, 12.0),
        ),
      ),
    );
  }
}

class _AdPlacementSkeleton extends StatefulWidget {
  const _AdPlacementSkeleton();

  @override
  State<_AdPlacementSkeleton> createState() => _AdPlacementSkeletonState();
}

class _AdPlacementSkeletonState extends State<_AdPlacementSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.35 + (_controller.value * 0.35);
        return Container(
          padding: EdgeInsets.all(r.gap(12)),
          decoration: BoxDecoration(
            color: dashboard.card,
            borderRadius: BorderRadius.circular(r.borderRadiusMd),
          ),
          child: Row(
            children: [
              _SkeletonBlock(
                opacity: opacity,
                width: r.w(104).clamp(88.0, 112.0),
                height: r.h(96).clamp(84.0, 104.0),
                borderRadius: r.gap(10),
              ),
              SizedBox(width: r.gap(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(
                      opacity: opacity,
                      height: r.sp(11).clamp(10.0, 12.0),
                      width: r.w(120).clamp(96.0, 140.0),
                    ),
                    SizedBox(height: r.gap(8)),
                    _SkeletonBlock(
                      opacity: opacity,
                      height: r.sp(15).clamp(13.0, 17.0),
                      width: double.infinity,
                    ),
                    SizedBox(height: r.gap(6)),
                    _SkeletonBlock(
                      opacity: opacity,
                      height: r.sp(12).clamp(11.0, 13.0),
                      width: r.w(160).clamp(130.0, 180.0),
                    ),
                    SizedBox(height: r.gap(12)),
                    _SkeletonBlock(
                      opacity: opacity,
                      height: r.h(28).clamp(26.0, 32.0),
                      width: r.w(88).clamp(76.0, 96.0),
                      borderRadius: r.gap(8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.opacity,
    required this.height,
    this.width,
    this.borderRadius = 6,
  });

  final double opacity;
  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dashboard.mutedText.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _AdPlacementFallbackCard extends StatelessWidget {
  const _AdPlacementFallbackCard();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);

    return Container(
      padding: EdgeInsets.all(r.gap(12)),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: r.w(104),
            height: r.h(96),
            child: Image.asset(
              AppConstants.dashboardPromoIllustrationAsset,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: r.gap(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.driversNeedPush,
                  textDirection: s.textDirection,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(11).clamp(10.0, 12.0),
                    color: dashboard.secondaryText,
                  ),
                ),
                SizedBox(height: r.gap(4)),
                Text(
                  s.eidDiscountAd,
                  textDirection: s.textDirection,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(15).clamp(13.0, 17.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: r.gap(10)),
                Material(
                  color: AppColors.loginButton,
                  borderRadius: BorderRadius.circular(r.gap(8)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.gap(14),
                      vertical: r.gap(6),
                    ),
                    child: Text(
                      s.learnMore,
                      textDirection: s.textDirection,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(11).clamp(10.0, 12.0),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
