import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';

class CommissionWalletRequiredModal extends StatelessWidget {
  const CommissionWalletRequiredModal({
    super.key,
    required this.onTopUp,
    required this.onTransfer,
  });

  final VoidCallback onTopUp;
  final VoidCallback onTransfer;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onTopUp,
    required VoidCallback onTransfer,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => CommissionWalletRequiredModal(
        onTopUp: onTopUp,
        onTransfer: onTransfer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: r.gap(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.gap(24)),
          decoration: BoxDecoration(
            color: dashboard.surface,
            borderRadius: BorderRadius.circular(r.borderRadiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: r.gap(24),
                offset: Offset(0, r.gap(8)),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r.w(56).clamp(48.0, 64.0),
                height: r.w(56).clamp(48.0, 64.0),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF4D6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.loginButton,
                  size: r.iconMd,
                ),
              ),
              ResponsiveGap(16),
              Text(
                s.commissionWalletRequiredTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(20).clamp(18.0, 22.0),
                  fontWeight: FontWeight.w800,
                  color: dashboard.primaryText,
                ),
              ),
              ResponsiveGap(10),
              Text(
                s.commissionWalletRequiredBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(15).clamp(14.0, 16.0),
                  height: 1.45,
                  color: dashboard.secondaryText,
                ),
              ),
              ResponsiveGap(20),
              _ModalActionButton(
                label: s.topUpCommissionWallet,
                onPressed: () {
                  Navigator.of(context).pop();
                  onTopUp();
                },
              ),
              ResponsiveGap(10),
              _ModalActionButton(
                label: s.transferFromMainWallet,
                filled: false,
                onPressed: () {
                  Navigator.of(context).pop();
                  onTransfer();
                },
              ),
              ResponsiveGap(8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  s.cancel,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(15).clamp(14.0, 16.0),
                    fontWeight: FontWeight.w600,
                    color: dashboard.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalActionButton extends StatelessWidget {
  const _ModalActionButton({
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Material(
      color: filled ? AppColors.loginButton : dashboard.inputFill,
      borderRadius: BorderRadius.circular(r.gap(6)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(r.gap(6)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: r.h(14)),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 17.0),
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : dashboard.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}
