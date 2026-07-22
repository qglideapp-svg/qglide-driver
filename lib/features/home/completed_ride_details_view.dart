import 'package:flutter/material.dart';

import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../config/dashboard_theme.dart';
import '../../shared/widgets/responsive_screen_shell.dart';
import 'models/driver_ride_details.dart';
import 'widgets/driver_ride_details_section.dart';

class CompletedRideDetailsView extends StatelessWidget {
  const CompletedRideDetailsView({
    required this.rideId,
    this.initialDetails,
    super.key,
  });

  final String rideId;
  final DriverRideDetails? initialDetails;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);

    return Scaffold(
      backgroundColor: dashboard.screenBackground,
      appBar: AppBar(
        backgroundColor: dashboard.screenBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: dashboard.primaryText,
            size: r.sp(18).clamp(16.0, 20.0),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.maxContentWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              r.gap(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Details',
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(27).clamp(24.0, 30.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                    height: 1.15,
                  ),
                ),
                ResponsiveGap(20),
                DriverRideDetailsSection(
                  rideId: rideId,
                  initialDetails: initialDetails,
                  showTitle: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
