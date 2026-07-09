import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';

class CancelTripModal extends StatefulWidget {
  const CancelTripModal({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => const CancelTripModal(),
    );
  }

  @override
  State<CancelTripModal> createState() => _CancelTripModalState();
}

class _CancelTripModalState extends State<CancelTripModal> {
  String? _selectedReason;

  void _dismiss() => Navigator.of(context).pop();

  void _confirm() {
    final reason = _selectedReason;
    if (reason == null) return;
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final cancelReasons = s.cancelTripReasons;
    final doneEnabled = _selectedReason != null;

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
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8E8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.block_rounded,
                  color: AppColors.goOfflineButton,
                  size: r.iconMd,
                ),
              ),
              ResponsiveGap(16),
              Text(
                s.cancelTrip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(22).clamp(20.0, 24.0),
                  fontWeight: FontWeight.w700,
                  color: dashboard.primaryText,
                ),
              ),
              ResponsiveGap(8),
              Text(
                s.cancelTripConfirm,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(15).clamp(14.0, 16.0),
                  color: dashboard.bodyText,
                  height: 1.45,
                ),
              ),
              ResponsiveGap(20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.reasonForCancellingTrip,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 15.0),
                    fontWeight: FontWeight.w500,
                    color: dashboard.secondaryText,
                  ),
                ),
              ),
              ResponsiveGap(8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: r.gap(14),
                  vertical: r.gap(2),
                ),
                decoration: BoxDecoration(
                  color: dashboard.iconBox,
                  borderRadius: BorderRadius.circular(r.gap(10)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedReason,
                    hint: Text(
                      s.select,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(15).clamp(14.0, 16.0),
                        color: dashboard.primaryText,
                      ),
                    ),
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: dashboard.primaryText,
                      size: r.iconSm,
                    ),
                    dropdownColor: dashboard.surface,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(15).clamp(14.0, 16.0),
                      color: dashboard.primaryText,
                    ),
                    items: cancelReasons
                        .map(
                          (reason) => DropdownMenuItem<String>(
                            value: reason,
                            child: Text(reason),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedReason = value),
                  ),
                ),
              ),
              ResponsiveGap(24),
              Row(
                children: [
                  Expanded(
                    child: _ModalActionButton(
                      label: s.cancel,
                      backgroundColor: dashboard.cancelButtonBg,
                      textColor: dashboard.secondaryText,
                      onPressed: _dismiss,
                    ),
                  ),
                  ResponsiveGap(12),
                  Expanded(
                    child: _ModalActionButton(
                      label: s.done,
                      backgroundColor: AppColors.goOfflineButton,
                      textColor: Colors.white,
                      onPressed: doneEnabled ? _confirm : null,
                    ),
                  ),
                ],
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
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(r.gap(10)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(r.gap(10)),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.h(14)),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(15).clamp(14.0, 17.0),
              fontWeight: FontWeight.w700,
              color: onPressed == null ? textColor.withValues(alpha: 0.45) : textColor,
            ),
          ),
        ),
      ),
    );
  }
}
