import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../services/phone_dialer_service.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../../../shared/widgets/ride_panel_shared.dart';

typedef ResolveOnDialPressed =
    Future<({Map<String, dynamic> response, String? phone})> Function();

class DialModal extends StatefulWidget {
  const DialModal({
    super.key,
    this.riderName,
    this.initialPhoneNumber,
    this.resolvePhoneNumber,
    this.resolveOnDialPressed,
    this.onCallInApp,
  });

  final String? riderName;
  final String? initialPhoneNumber;
  final Future<String?> Function()? resolvePhoneNumber;
  final ResolveOnDialPressed? resolveOnDialPressed;
  final VoidCallback? onCallInApp;

  static Future<void> show(
    BuildContext context, {
    String? riderName,
    String? initialPhoneNumber,
    Future<String?> Function()? resolvePhoneNumber,
    ResolveOnDialPressed? resolveOnDialPressed,
    VoidCallback? onCallInApp,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => DialModal(
        riderName: riderName,
        initialPhoneNumber: initialPhoneNumber,
        resolvePhoneNumber: resolvePhoneNumber,
        resolveOnDialPressed: resolveOnDialPressed,
        onCallInApp: onCallInApp,
      ),
    );
  }

  @override
  State<DialModal> createState() => _DialModalState();
}

class _DialModalState extends State<DialModal> {
  String? _phone;
  var _isLoadingPhone = false;
  var _isDialing = false;

  @override
  void initState() {
    super.initState();
    _phone = _cleanPhone(widget.initialPhoneNumber);
    if (widget.resolvePhoneNumber != null) {
      if (_phone == null) _isLoadingPhone = true;
      unawaited(_refreshPhone());
    }
  }

  Future<void> _refreshPhone() async {
    final resolver = widget.resolvePhoneNumber;
    if (resolver == null) return;

    final resolved = _cleanPhone(await resolver());
    if (!mounted) return;

    setState(() {
      if (resolved != null) _phone = resolved;
      _isLoadingPhone = false;
    });
  }

  Future<void> _handleDialNumber() async {
    if (_isDialing) return;

    var phone = _cleanPhone(_phone);

    // Open the dialer immediately when we already have a number. iOS requires
    // tel: to be launched from the user tap without an async gap in between.
    if (phone != null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();

      final error = await PhoneDialerService.launch(phone);
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    setState(() => _isDialing = true);

    final resolveOnDial = widget.resolveOnDialPressed;
    if (resolveOnDial != null) {
      final result = await resolveOnDial();
      phone = _cleanPhone(result.phone) ?? phone;
    } else if (widget.resolvePhoneNumber != null) {
      if (!_isLoadingPhone) {
        setState(() => _isLoadingPhone = true);
      }
      await _refreshPhone();
      phone = _cleanPhone(_phone);
    }

    if (!mounted) return;

    setState(() {
      _isDialing = false;
      _isLoadingPhone = false;
    });

    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rider phone number is not available.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    final error = await PhoneDialerService.launch(phone);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  static String? _cleanPhone(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final displayName = widget.riderName?.trim().isNotEmpty == true
        ? widget.riderName!.trim()
        : 'your rider';
    final displayPhone = _phone;

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
                color: dashboard.panelFill,
                borderRadius: BorderRadius.circular(r.borderRadiusLg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayPhone ?? 'Call Rider',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(22).clamp(20.0, 24.0),
                      fontWeight: FontWeight.w700,
                      color: dashboard.primaryText,
                    ),
                  ),
                  ResponsiveGap(12),
                  Text(
                    _isLoadingPhone && displayPhone == null
                        ? 'Fetching rider phone number...'
                        : displayPhone == null
                            ? 'Rider phone number is not available right now.'
                            : 'Call $displayName using their phone number.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(16).clamp(15.0, 18.0),
                      color: dashboard.secondaryText,
                      height: 1.45,
                    ),
                  ),
                  ResponsiveGap(24),
                  RideActionButton(
                    label: 'Dial Number',
                    color: AppColors.loginButton,
                    isLoading: _isDialing || (_isLoadingPhone && displayPhone == null),
                    onPressed: _handleDialNumber,
                  ),
                  ResponsiveGap(12),
                  RideActionButton(
                    label: 'Call in app',
                    color: dashboard.cancelButtonBg,
                    textColor: dashboard.secondaryText,
                    onPressed: () {
                      if (_isDialing || (_isLoadingPhone && displayPhone == null)) {
                        return;
                      }
                      Navigator.of(context).pop();
                      widget.onCallInApp?.call();
                    },
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
      color: dashboard.card,
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
            color: dashboard.mutedText,
          ),
        ),
      ),
    );
  }
}
