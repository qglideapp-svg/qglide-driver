import 'package:flutter/material.dart';

import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../models/nearby_ride_offer.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../../../shared/widgets/ride_panel_shared.dart';

class ActivePickupPanel extends StatelessWidget {
  const ActivePickupPanel({
    super.key,
    required this.offer,
    required this.onCancelRide,
    required this.onPickupCompleted,
    required this.onOpenWithWaze,
    required this.onCall,
    required this.onMessage,
    this.isCompletingPickup = false,
    this.isCancellingRide = false,
    this.progress = 0,
  });

  final NearbyRideOffer offer;
  final VoidCallback onCancelRide;
  final VoidCallback onPickupCompleted;
  final VoidCallback onOpenWithWaze;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final bool isCompletingPickup;
  final bool isCancellingRide;
  final double progress;

  bool get _isBusy => isCompletingPickup || isCancellingRide;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return RidePanelShell(
      flatBackground: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RideContactActionBar(
            onCall: onCall,
            onMessage: onMessage,
          ),
          ResponsiveGap(12),
          RideRequestProfile(
            riderName: offer.riderName,
            riderPhotoUrl: offer.riderPhotoUrl,
          ),
          ResponsiveGap(14),
          RidePickupTitle(title: offer.pickupTitle),
          ResponsiveGap(10),
          RideLocationPill(label: offer.pickupAddress),
          ResponsiveGap(16),
          RideLegProgressBar(
            label: s.pickUpDestination,
            progress: progress,
          ),
          ResponsiveGap(16),
          AbsorbPointer(
            absorbing: _isBusy,
            child: Opacity(
              opacity: _isBusy ? 0.85 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RideActionButton(
                    label: s.openWithWaze,
                    color: const Color(0xFF1F6FEA),
                    onPressed: onOpenWithWaze,
                  ),
                  ResponsiveGap(12),
                  Row(
                    children: [
                      Expanded(
                        child: RideActionButton(
                          label: s.cancelRide,
                          color: dashboard.cancelButtonBg,
                          textColor: dashboard.secondaryText,
                          isLoading: isCancellingRide,
                          onPressed: onCancelRide,
                        ),
                      ),
                      SizedBox(width: r.gap(12)),
                      Expanded(
                        child: RideActionButton(
                          label: s.pickUpCompleted,
                          color: const Color(0xFFE3AA00),
                          isLoading: isCompletingPickup,
                          onPressed: onPickupCompleted,
                        ),
                      ),
                    ],
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
