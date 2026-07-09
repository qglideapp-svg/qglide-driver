import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_constants.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../models/nearby_ride_offer.dart';
import 'driver_ad_placement_banner.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/ride_panel_shared.dart';

class RideDashboardPanel extends StatelessWidget {
  const RideDashboardPanel({
    super.key,
    required this.offer,
    required this.isOnline,
    required this.isUpdatingOnlineStatus,
    required this.onGoOnlinePressed,
    required this.onCancelRide,
    required this.onStartRide,
    required this.onCall,
    required this.onMessage,
    this.isCancellingRide = false,
    this.isStartingRide = false,
  });

  final NearbyRideOffer offer;
  final bool isOnline;
  final bool isUpdatingOnlineStatus;
  final VoidCallback onGoOnlinePressed;
  final VoidCallback onCancelRide;
  final VoidCallback onStartRide;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final bool isCancellingRide;
  final bool isStartingRide;

  bool get _isBusy => isCancellingRide || isStartingRide;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned.fill(
          child: dashboard.panelImage(AppConstants.dashboardPanelAsset),
        ),
        Positioned.fill(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              r.gap(16),
              r.h(24),
              r.gap(16),
              r.gap(12),
            ),
            child: Column(
              children: [
                RideContactActionBar(
                  onCall: onCall,
                  onMessage: onMessage,
                ),
                SizedBox(height: r.gap(12)),
                _PickupLocationBar(offer: offer),
                SizedBox(height: r.gap(14)),
                const DriverAdPlacementBanner(),
                SizedBox(height: r.gap(20)),
                AbsorbPointer(
                  absorbing: _isBusy,
                  child: Opacity(
                    opacity: _isBusy ? 0.85 : 1,
                    child: Row(
                      children: [
                        Expanded(
                          child: RideActionButton(
                            label: s.cancelRide,
                            color: dashboard.isDark
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFF1F1F1),
                            textColor: dashboard.secondaryText,
                            isLoading: isCancellingRide,
                            onPressed: onCancelRide,
                          ),
                        ),
                        SizedBox(width: r.gap(12)),
                        Expanded(
                          child: RideActionButton(
                            label: s.startRide,
                            color: const Color(0xFFE3AA00),
                            isLoading: isStartingRide,
                            onPressed: onStartRide,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: r.goOnlineNotchTop(),
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              width: r.w(136).clamp(124.0, 156.0),
              child: _GoOnlineButton(
                isOnline: isOnline,
                isLoading: isUpdatingOnlineStatus,
                onPressed: onGoOnlinePressed,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoOnlineButton extends StatelessWidget {
  const _GoOnlineButton({
    required this.isOnline,
    required this.onPressed,
    this.isLoading = false,
  });

  final bool isOnline;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final buttonColor =
        isOnline ? AppColors.goOfflineButton : AppColors.loginButton;

    return Material(
      color: buttonColor.withValues(alpha: isLoading ? 0.7 : 1),
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: buttonColor.withValues(alpha: 0.45),
      child: InkWell(
        onTap: () {
          if (isLoading) return;
          onPressed();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: r.h(10)),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: r.sp(20).clamp(18.0, 22.0),
                  height: r.sp(20).clamp(18.0, 22.0),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  isOnline ? s.goOffline : s.goOnline,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _PickupLocationBar extends StatelessWidget {
  const _PickupLocationBar({required this.offer});

  final NearbyRideOffer offer;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);

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
                  s.pickUpLocation,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(11).clamp(10.0, 12.0),
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: r.gap(2)),
                Text(
                  offer.pickupAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                offer.durationDisplay,
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
