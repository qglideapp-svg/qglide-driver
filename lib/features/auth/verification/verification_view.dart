import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_status_service.dart';
import '../../../utils/driver_auth_navigation.dart';
import '../widgets/auth_top_toast.dart';
import '../widgets/auth_widgets.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import 'verification_args.dart';
import 'verification_controller.dart';

class VerificationView extends ConsumerStatefulWidget {
  const VerificationView({super.key, required this.args});

  final VerificationArgs args;

  @override
  ConsumerState<VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends ConsumerState<VerificationView> {
  String get _cacheKey => widget.args.cacheKey;

  VerificationController? _controller;

  @override
  void initState() {
    super.initState();
    if (!widget.args.hasValidPhone) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await AuthService.signOut();
        if (!mounted) return;
        await Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
      });
      return;
    }
    _controller = ref.read(verificationControllerProvider(_cacheKey));
    final controller = _controller!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.onAutoVerifyComplete = _handleAutoVerifyResult;
      controller.addListener(_onControllerUpdated);
      for (final node in controller.focusNodes) {
        node.addListener(_onFocusChange);
      }
      controller.focusNodes.first.requestFocus();
      unawaited(_sendInitialCode());
    });
  }

  void _onControllerUpdated() {
    if (mounted) setState(() {});
  }

  VerificationController get _activeController => _controller!;

  Future<void> _handleAutoVerifyResult(Map<String, dynamic> result) async {
    if (!mounted) return;
    await _handleVerificationResult(result);
  }

  Future<void> _sendInitialCode() async {
    final result = await _activeController.sendCode();
    if (!mounted) return;
    await _handleSendCodeResponse(result);
  }

  Future<void> _tryAutoConfirm() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (!controller.hasCompleteOtp || !controller.canConfirm) return;
    await _handleConfirm();
  }

  Future<void> _handleResend() async {
    final result = await _activeController.resendCode();
    if (!mounted) return;
    await _handleSendCodeResponse(result);
  }

  Future<void> _handleSendCodeResponse(Map<String, dynamic> result) async {
    if (result['success'] == true) {
      final data = result['data'];
      final autoVerified =
          data is Map && data['sms_sent'] != true;
      if (autoVerified) {
        await _handleVerificationResult(result);
        return;
      }

      final restored = data is Map && data['restored'] == true;
      if (restored) {
        AuthTopToast.showSuccess(
          context,
          AppStringsScope.of(context).verificationRestoredSession,
        );
        return;
      }

      final message = data is Map ? data['message']?.toString() : null;
      if (message != null && message.isNotEmpty) {
        AuthTopToast.showSuccess(context, message);
      } else {
        AuthTopToast.showSuccess(context, AppStringsScope.of(context).verificationCodeSent);
      }
      return;
    }

    final s = AppStringsScope.of(context);
    final error = _activeController.errorMessage ??
        AuthService.extractErrorMessage(
          result,
          fallback: s.errSendCode,
        );
    AuthTopToast.showError(context, error);
  }

  Future<void> _handleConfirm() async {
    if (_activeController.otpCode.length != 6) {
      AuthTopToast.showError(
        context,
        AppStringsScope.of(context).enterFullOtpCode,
      );
      return;
    }

    final result = await _activeController.confirmCode();
    if (!mounted) return;
    await _handleVerificationResult(result);
  }

  Future<void> _handleVerificationResult(Map<String, dynamic> result) async {
    if (result['success'] == true) {
      final data = result['data'];
      final message = data is Map ? data['message'] as String? : null;
      if (message != null && message.isNotEmpty) {
        AuthTopToast.showSuccess(context, message);
      }
      if (!mounted) return;
      await DriverStatusService.clearStored();
      await AuthService.markSignupResumeAfterPhoneVerification();
      await AuthService.ensureAuthenticatedSession();
      if (!mounted) return;
      await DriverAuthNavigation.navigateAfterAuth(context);
      return;
    }

    final s = AppStringsScope.of(context);
    final error = _activeController.errorMessage ??
        AuthService.extractErrorMessage(
          result,
          fallback: s.errVerification,
        );
    final message = result['firebase_code_consumed'] == true
        ? '$error${s.resendCodeForNewSms}'
        : error;
    AuthTopToast.showError(context, message);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.onAutoVerifyComplete = null;
      controller.removeListener(_onControllerUpdated);
      for (final node in controller.focusNodes) {
        node.removeListener(_onFocusChange);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !widget.args.hasValidPhone) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final controller = _activeController;
    ref.watch(verificationControllerProvider(_cacheKey));
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isBusy = controller.isBusy;

    return ResponsiveScreenShell(
      backgroundAsset: theme.primaryAuthBackgroundAsset,
      footer: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: r.bodyStyle(color: theme.mutedText),
          children: [
            TextSpan(text: s.needHelp),
            TextSpan(
              text: s.contactUs,
              recognizer: TapGestureRecognizer()..onTap = () {},
              style: TextStyle(
                color: theme.linkAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AppLogo(height: r.logoHeight),
          ),
          ResponsiveGap(48),
          Text(
            s.enterVerificationCodeTitle,
            textAlign: TextAlign.center,
            style: r.titleStyle(color: onSurface),
          ),
          ResponsiveGap(16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: r.subtitleStyle(color: theme.mutedText),
              children: [
                TextSpan(
                  text: controller.instructionText,
                ),
                TextSpan(
                  text: widget.args.phoneNumber,
                  style: TextStyle(
                    color: theme.linkAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (controller.isSendingCode || controller.isWaitingForCode) ...[
            ResponsiveGap(12),
            Text(
              s.instructionCompleteBrowserCheck,
              textAlign: TextAlign.center,
              style: r.bodyStyle(color: theme.mutedText),
            ),
          ],
          if (controller.codeReadyForEntry && !controller.isAutoVerifying) ...[
            ResponsiveGap(12),
            Text(
              controller.autoReadTimedOut
                  ? s.smsManualEntryTimedOut
                  : s.smsManualEntry,
              textAlign: TextAlign.center,
              style: r.bodyStyle(color: theme.mutedText),
            ),
          ],
          ResponsiveGap(controller.codeReadyForEntry ? 28 : 40),
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 0,
              width: 0,
              child: TextField(
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  if (value.length < 6) return;
                  controller.fillOtp(value);
                  setState(() {});
                  unawaited(_tryAutoConfirm());
                },
              ),
            ),
          ),
          AutofillGroup(
            child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = r.contentPadding.horizontal / 2;
              final boxSize = r.otpBoxSize(horizontalPadding);
              final spacing = r.gap(8);

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (index) => _buildOtpField(
                    index,
                    boxSize: boxSize,
                    spacing: spacing,
                    enabled: !isBusy,
                  ),
                ),
              );
            },
            ),
          ),
          ResponsiveGap(28),
          TextButton(
            onPressed: controller.canResend
                ? () => unawaited(_handleResend())
                : null,
            style: TextButton.styleFrom(
              foregroundColor: onSurface,
              disabledForegroundColor: theme.iconMuted,
            ),
            child: Text(
              controller.isSendingCode ? s.sendingCode : s.resendCode,
              style: TextStyle(
                fontFamily: AppFonts.plusJakartaSans,
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ResponsiveGap(8),
          Text(
            controller.timerText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.plusJakartaSans,
              fontSize: r.subtitleSize,
              fontWeight: FontWeight.w600,
              color: theme.linkAccent,
            ),
          ),
          ResponsiveGap(40),
          AuthPrimaryButton(
            label: controller.isAutoVerifying
                ? s.verifyingAutomatically
                : controller.isConfirming
                    ? s.verifying
                    : controller.isSendingCode
                        ? s.sendingCode
                        : s.confirm,
            onPressed: controller.canConfirm
                ? () => unawaited(_handleConfirm())
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpField(
    int index, {
    required double boxSize,
    required double spacing,
    required bool enabled,
  }) {
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final controller = _activeController;
    final isFocused = controller.focusNodes[index].hasFocus;

    return Container(
      width: boxSize,
      height: boxSize * 1.13,
      margin: EdgeInsets.only(left: index == 0 ? 0 : spacing),
      decoration: BoxDecoration(
        color: theme.authFieldFill,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
        border: Border.all(
          color: isFocused
              ? theme.authFocusBorder
              : theme.authFieldBorder.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller.digitControllers[index],
        focusNode: controller.focusNodes[index],
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: TextStyle(
          fontFamily: AppFonts.plusJakartaSans,
          fontSize: r.sp(22),
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
        onChanged: (value) {
          if (value.isEmpty) {
            controller.onDigitDeleted(index);
          } else {
            controller.onDigitChanged(index, value);
          }
          setState(() {});
          if (controller.hasCompleteOtp && controller.canConfirm) {
            unawaited(_handleConfirm());
          }
        },
        onTap: () {
          controller.digitControllers[index].selection =
              TextSelection.collapsed(
            offset: controller.digitControllers[index].text.length,
          );
        },
      ),
    );
  }
}
