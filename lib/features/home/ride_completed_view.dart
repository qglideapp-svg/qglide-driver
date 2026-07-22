import 'package:flutter/material.dart';

import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../config/dashboard_theme.dart';
import '../../shared/widgets/animated_success_badge.dart';
import '../../shared/widgets/responsive_screen_shell.dart';
import '../../shared/widgets/ride_panel_shared.dart';
import 'models/driver_ride_details.dart';
import 'widgets/driver_ride_details_section.dart';

class RideCompletedView extends StatelessWidget {
  const RideCompletedView({
    required this.rideId,
    required this.onDone,
    this.initialDetails,
    super.key,
  });

  final String rideId;
  final DriverRideDetails? initialDetails;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onDone();
      },
      child: Scaffold(
        backgroundColor: dashboard.screenBackground,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.maxContentWidth),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        r.gap(12),
                        horizontalPadding,
                        r.gap(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: AnimatedSuccessBadge(
                              scale: r.isCompact ? 0.82 : 0.88,
                            ),
                          ),
                          ResponsiveGap(r.isCompact ? 14 : 18),
                          Text(
                            'Ride Completed',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.satoshi,
                              fontSize: r.sp(25).clamp(22.0, 28.0),
                              fontWeight: FontWeight.w700,
                              color: dashboard.primaryText,
                            ),
                          ),
                          ResponsiveGap(r.isCompact ? 8 : 10),
                          Text(
                            'The trip has been completed successfully. Payment has been processed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.satoshi,
                              fontSize: r.sp(16).clamp(15.0, 18.0),
                              color: dashboard.secondaryText,
                              height: 1.45,
                            ),
                          ),
                          ResponsiveGap(r.isCompact ? 22 : 28),
                          DriverRideDetailsSection(
                            rideId: rideId,
                            initialDetails: initialDetails,
                            showTitle: false,
                            forceCompleted: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      r.gap(16),
                    ),
                    child: RideActionButton(
                      label: 'Done',
                      color: const Color(0xFFE3AA00),
                      onPressed: onDone,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
