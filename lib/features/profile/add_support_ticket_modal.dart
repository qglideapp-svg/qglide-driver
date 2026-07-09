import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../config/dashboard_theme.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../shared/widgets/responsive_screen_shell.dart';
import '../../shared/widgets/ride_panel_shared.dart';

class AddSupportTicketModal extends StatefulWidget {
  const AddSupportTicketModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).pushNamed<bool>(AppRoutes.addSupportTicket);
  }

  @override
  State<AddSupportTicketModal> createState() => _AddSupportTicketModalState();
}

class _AddSupportTicketModalState extends State<AddSupportTicketModal> {
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: r.gap(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                r.gap(24),
                r.gap(36),
                r.gap(24),
                r.gap(24),
              ),
              decoration: BoxDecoration(
                color: dashboard.surface,
                borderRadius: BorderRadius.circular(r.borderRadiusLg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Title of your ticket',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(22).clamp(20.0, 24.0),
                      fontWeight: FontWeight.w700,
                      color: dashboard.primaryText,
                    ),
                  ),
                  ResponsiveGap(20),
                  TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Enter ticket title',
                      hintStyle: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(16).clamp(15.0, 18.0),
                        color: dashboard.mutedText,
                      ),
                      filled: true,
                      fillColor: dashboard.inputFill,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: r.gap(14),
                        vertical: r.gap(14),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.gap(10)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(16).clamp(15.0, 18.0),
                      color: dashboard.primaryText,
                    ),
                  ),
                  ResponsiveGap(24),
                  RideActionButton(
                    label: 'Submit Ticket',
                    color: AppColors.loginButton,
                    onPressed: _submit,
                  ),
                  ResponsiveGap(12),
                  RideActionButton(
                    label: 'Cancel',
                    color: dashboard.cancelButtonBg,
                    textColor: dashboard.secondaryText,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Positioned(
              top: r.gap(12),
              right: r.gap(12),
              child: _CloseButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final size = r.w(32).clamp(28.0, 36.0);

    return Material(
      color: dashboard.iconBox,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.close_rounded,
            size: r.iconSm,
            color: dashboard.secondaryText,
          ),
        ),
      ),
    );
  }
}
