import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../models/nearby_ride_offer.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../../../shared/widgets/ride_panel_shared.dart';

class RideRequestPanel extends StatelessWidget {
  const RideRequestPanel({
    super.key,
    required this.offer,
    required this.onIgnore,
    required this.onAccept,
    required this.onExpired,
    this.isAccepting = false,
    this.isDeclining = false,
  });

  final NearbyRideOffer offer;
  final VoidCallback onIgnore;
  final VoidCallback onAccept;
  final VoidCallback onExpired;
  final bool isAccepting;
  final bool isDeclining;

  bool get _isBusy => isAccepting || isDeclining;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return RidePanelShell(
      flatBackground: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RideRequestProfile(
            riderName: offer.riderName,
            riderRating: offer.riderRating,
            riderPhotoUrl: offer.riderPhotoUrl,
            countdownDuration:
                isAccepting ? null : AppConstants.rideRequestAcceptDuration,
            onCountdownComplete: isAccepting ? null : onExpired,
          ),
          ResponsiveGap(14),
          RidePickupTitle(title: offer.pickupTitle),
          ResponsiveGap(10),
          RideLocationPill(label: offer.pickupAddress),
          ResponsiveGap(14),
          _RideStatsBar(offer: offer),
          ResponsiveGap(12),
          _DropOffBar(
            r: r,
            dropoffAddress: offer.dropoffAddress,
          ),
          ResponsiveGap(16),
          AbsorbPointer(
            absorbing: _isBusy,
            child: Opacity(
              opacity: _isBusy ? 0.85 : 1,
              child: Row(
                children: [
                  Expanded(
                    child: RideActionButton(
                      label: 'Ignore Booking',
                      color: const Color(0xFFBF1F1F),
                      isLoading: isDeclining,
                      onPressed: onIgnore,
                    ),
                  ),
                  SizedBox(width: r.gap(12)),
                  Expanded(
                    child: RideActionButton(
                      label: 'Accept Booking',
                      color: const Color(0xFF049327),
                      isLoading: isAccepting,
                      onPressed: onAccept,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideStatsBar extends StatelessWidget {
  const _RideStatsBar({required this.offer});

  final NearbyRideOffer offer;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: r.gap(12),
        vertical: r.gap(14),
      ),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RideStatItem(
              r: r,
              icon: Icons.schedule_rounded,
              value: offer.durationDisplay,
            ),
          ),
          Expanded(
            child: _RideStatItem(
              r: r,
              icon: Icons.payments_outlined,
              value: offer.fareDisplay,
            ),
          ),
          Expanded(
            child: _RideStatItem(
              r: r,
              icon: Icons.route_rounded,
              value: offer.distanceDisplay,
            ),
          ),
        ],
      ),
    );
  }
}

class _RideStatItem extends StatelessWidget {
  const _RideStatItem({
    required this.r,
    required this.icon,
    required this.value,
  });

  final AppResponsive r;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: r.iconSm,
          color: dashboard.mutedText,
        ),
        SizedBox(width: r.gap(4)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(15).clamp(14.0, 17.0),
              fontWeight: FontWeight.w600,
              color: dashboard.statValue,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DropOffBar extends StatelessWidget {
  const _DropOffBar({
    required this.r,
    required this.dropoffAddress,
  });

  final AppResponsive r;
  final String dropoffAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFE3AA00),
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: r.w(36).clamp(32.0, 40.0),
            height: r.w(36).clamp(32.0, 40.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: r.iconSm,
              color: const Color(0xFFE3AA00),
            ),
          ),
          SizedBox(width: r.gap(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Drop off location',
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(13).clamp(12.0, 15.0),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: r.gap(2)),
                Text(
                  dropoffAddress,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(17).clamp(16.0, 19.0),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
