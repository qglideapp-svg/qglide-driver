import 'package:flutter/material.dart';

import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../utils/pickup_wait_time.dart';
import '../../../shared/widgets/app_strings_scope.dart';

class PickupWaitTimePanel extends StatelessWidget {
  const PickupWaitTimePanel({
    super.key,
    required this.snapshot,
  });

  final PickupWaitTimeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final elapsedLabel = snapshot.formatDuration(snapshot.elapsed);
    final inGrace = snapshot.isInGracePeriod;
    final graceLabel = snapshot.formatDuration(snapshot.graceRemaining);
    final billableLabel = snapshot.formatDuration(snapshot.billableWait);
    final feePerMinute = snapshot.feePerMinute;
    final accent = inGrace ? const Color(0xFFE3AA00) : Colors.orange.shade800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.gap(14)),
      decoration: BoxDecoration(
        color: inGrace
            ? const Color(0xFFE3AA00).withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
        border: Border.all(
          color: inGrace
              ? const Color(0xFFE3AA00).withValues(alpha: 0.35)
              : Colors.orange.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: accent, size: r.iconSm),
              SizedBox(width: r.gap(8)),
              Expanded(
                child: Text(
                  s.waitTimeTitle,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                  ),
                ),
              ),
              Text(
                elapsedLabel,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(22).clamp(20.0, 24.0),
                  fontWeight: FontWeight.w700,
                  color: accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SizedBox(height: r.gap(8)),
          Text(
            inGrace
                ? s.waitTimeGraceMessage(snapshot.graceMinutes, graceLabel)
                : s.waitTimeBillableMessage(billableLabel),
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(12).clamp(11.0, 14.0),
              color: dashboard.secondaryText,
              height: 1.35,
            ),
          ),
          if (!inGrace && feePerMinute != null && feePerMinute > 0) ...[
            SizedBox(height: r.gap(6)),
            Text(
              s.waitTimeFeePerMinute(feePerMinute),
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(12).clamp(11.0, 13.0),
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
          if (!inGrace &&
              snapshot.estimatedChargeQar != null &&
              snapshot.estimatedChargeQar! > 0) ...[
            SizedBox(height: r.gap(4)),
            Text(
              s.waitTimeEstimatedCharge(snapshot.estimatedChargeQar!),
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(12).clamp(11.0, 13.0),
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
          SizedBox(height: r.gap(6)),
          Text(
            s.waitTimeStartRideHint,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(12).clamp(11.0, 13.0),
              fontWeight: FontWeight.w600,
              color: dashboard.bodyText,
            ),
          ),
        ],
      ),
    );
  }
}
