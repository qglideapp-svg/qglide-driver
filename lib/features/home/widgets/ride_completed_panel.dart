import 'package:flutter/material.dart';

import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../shared/widgets/animated_success_badge.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../../../shared/widgets/ride_panel_shared.dart';

class RideCompletedPanel extends StatelessWidget {
  const RideCompletedPanel({
    super.key,
    required this.onDetails,
    required this.onDone,
  });

  final VoidCallback onDetails;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return RidePanelShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          ResponsiveGap(r.isCompact ? 14 : 18),
          Row(
            children: [
              Expanded(
                child: RideActionButton(
                  label: 'Details',
                  color: dashboard.cancelButtonBg,
                  textColor: dashboard.secondaryText,
                  onPressed: onDetails,
                ),
              ),
              SizedBox(width: r.gap(12)),
              Expanded(
                child: RideActionButton(
                  label: 'Done',
                  color: const Color(0xFFE3AA00),
                  onPressed: onDone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
