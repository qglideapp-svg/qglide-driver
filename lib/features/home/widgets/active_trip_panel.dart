import 'package:flutter/material.dart';

import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../models/nearby_ride_offer.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../../../shared/widgets/ride_panel_shared.dart';

class ActiveTripPanel extends StatelessWidget {
  const ActiveTripPanel({
    super.key,
    required this.offer,
    required this.onCompleteTrip,
    required this.onOpenWithWaze,
    this.isCompletingTrip = false,
    this.progress = 0,
  });

  final NearbyRideOffer offer;
  final VoidCallback onCompleteTrip;
  final VoidCallback onOpenWithWaze;
  final bool isCompletingTrip;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dashboard.panelFill,
        borderRadius: BorderRadius.circular(r.borderRadiusLg),
        boxShadow: [
          BoxShadow(
            color: dashboard.panelShadow,
            blurRadius: r.gap(20),
            offset: Offset(0, r.gap(4)),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              r.gap(16),
              r.tripProfileTopOffset(),
              r.gap(16),
              0,
            ),
            child: RideRequestProfile(
              riderName: offer.riderName,
              riderPhotoUrl: offer.riderPhotoUrl,
            ),
          ),
          SizedBox(height: r.gap(8)),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                r.gap(16),
                0,
                r.gap(16),
                r.gap(12),
              ),
              child: Column(
                children: [
                  _TripDestinationBar(offer: offer),
                  ResponsiveGap(12),
                  _RiderStopInfoBox(offer: offer),
                  ResponsiveGap(14),
                  RideLegProgressBar(
                    label: s.tripToDestination,
                    progress: progress,
                  ),
                  ResponsiveGap(14),
                  RideActionButton(
                    label: s.openWithWaze,
                    color: const Color(0xFF1F6FEA),
                    onPressed: onOpenWithWaze,
                  ),
                  ResponsiveGap(12),
                  RideActionButton(
                    label: s.completeTrip,
                    color: const Color(0xFFE3AA00),
                    isLoading: isCompletingTrip,
                    onPressed: onCompleteTrip,
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

class _TripDestinationBar extends StatelessWidget {
  const _TripDestinationBar({required this.offer});

  final NearbyRideOffer offer;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final destinationAddress = offer.hasRiderStopRequest &&
            offer.pendingStopAddress != null
        ? offer.pendingStopAddress!
        : offer.dropoffAddress;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFE3AA00),
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  s.destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(11).clamp(10.0, 12.0),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: r.gap(2)),
                Text(
                  destinationAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.gap(8)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                offer.durationDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(16).clamp(14.0, 18.0),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: r.gap(2)),
              Text(
                offer.distanceDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(11).clamp(10.0, 12.0),
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiderStopInfoBox extends StatelessWidget {
  const _RiderStopInfoBox({required this.offer});

  final NearbyRideOffer offer;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    if (!offer.hasRiderStopRequest) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(r.gap(14)),
        decoration: BoxDecoration(
          color: dashboard.card,
          borderRadius: BorderRadius.circular(r.borderRadiusMd),
          border: Border.all(color: dashboard.borderSubtle),
        ),
        child: Text(
          s.riderAddsStopHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(12).clamp(11.0, 13.0),
            color: dashboard.secondaryText,
            height: 1.4,
          ),
        ),
      );
    }

    final addedStops = offer.stops;
    final hasAddedStops = addedStops.isNotEmpty;
    final stopAddress = offer.pendingStopAddress ?? '--';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(14)),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
        border: Border.all(color: const Color(0xFFE3AA00).withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_location_alt_outlined,
                size: r.iconSm,
                color: const Color(0xFFE3AA00),
              ),
              SizedBox(width: r.gap(8)),
              Expanded(
                child: Text(
                  hasAddedStops
                      ? addedStops.length == 1
                          ? s.riderAddedAStop
                          : s.riderAddedStops(addedStops.length)
                      : s.riderRequestedStop,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(13).clamp(12.0, 14.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.bodyText,
                  ),
                ),
              ),
            ],
          ),
          ResponsiveGap(12),
          if (hasAddedStops) ...[
            for (var i = 0; i < addedStops.length; i++) ...[
              if (i > 0) ResponsiveGap(10),
              _StopDetailRow(
                label: addedStops.length == 1
                    ? s.addedStop
                    : s.addedStopNumber(i + 1),
                value: addedStops[i].address,
                highlight: true,
              ),
            ],
            ResponsiveGap(10),
            _StopDetailRow(
              label: s.finalDestination,
              value: offer.dropoffAddress,
              muted: true,
            ),
          ] else ...[
            _StopDetailRow(
              label: s.currentDestination,
              value: offer.dropoffAddress,
              muted: true,
            ),
            ResponsiveGap(10),
            _StopDetailRow(
              label: s.newStop,
              value: stopAddress,
              highlight: true,
            ),
          ],
          if (offer.requestedFare != null) ...[
            ResponsiveGap(10),
            _StopDetailRow(
              label: s.updatedFare,
              value: offer.requestedFareDisplay,
              highlight: true,
            ),
          ] else if (hasAddedStops && offer.estimatedFare != null) ...[
            ResponsiveGap(10),
            _StopDetailRow(
              label: s.estimatedFare,
              value: offer.fareDisplay,
              highlight: true,
            ),
          ],
          ResponsiveGap(12),
          Text(
            hasAddedStops
                ? s.continueToAddedStopHint
                : s.reviewStopChangeHint,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(11).clamp(10.0, 12.0),
              color: dashboard.secondaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StopDetailRow extends StatelessWidget {
  const _StopDetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(11).clamp(10.0, 12.0),
            color: dashboard.secondaryText,
          ),
        ),
        SizedBox(height: r.gap(4)),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(13).clamp(12.0, 14.0),
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            color: muted
                ? dashboard.secondaryText
                : highlight
                    ? const Color(0xFFE3AA00)
                    : dashboard.bodyText,
          ),
        ),
      ],
    );
  }
}
