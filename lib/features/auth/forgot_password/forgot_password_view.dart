import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_responsive.dart';
import '../../../config/app_strings.dart';
import '../../../config/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import 'forgot_password_controller.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import '../widgets/auth_top_toast.dart';
import '../widgets/auth_widgets.dart';
import 'forgot_password_success_modal.dart';

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView>
    with AuthValidationToastState {
  final _emailController = TextEditingController();

  ForgotPasswordController get _controller =>
      ref.read(forgotPasswordControllerProvider);

  Future<void> _handleSendResetLink() async {
    final trimmedEmail = _emailController.text.trim();
    final message = await _controller.sendResetLink(email: trimmedEmail);
    if (!mounted || message == null) return;

    await ForgotPasswordSuccessModal.show(
      context,
      email: trimmedEmail,
      onBackToLogin: () {
        Navigator.of(context).pop();
        _goToLogin();
      },
    );
  }

  void _goToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(forgotPasswordControllerProvider);
    presentAuthValidationError(controller.errorMessage);
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ResponsiveScreenShell(
      backgroundAsset: theme.formAuthBackgroundAsset,
      padding: r.signupTopPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _goToLogin,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: r.iconSm,
                color: onSurface,
              ),
            ),
          ),
          ResponsiveGap(16),
          Text(
            s.forgotPasswordTitleQuestion,
            style: r.titleStyle(color: onSurface),
          ),
          ResponsiveGap(8),
          Text(
            s.forgotPasswordSubtitleRelaxed,
            style: r.subtitleStyle(color: theme.mutedText),
          ),
          ResponsiveGap(28),
          AuthTextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            hintText: s.emailAddress,
            prefix: Icon(Icons.email_outlined, size: r.iconSm, color: theme.iconMuted),
          ),
          ResponsiveGap(24),
          AuthPrimaryButton(
            label: controller.isLoading ? s.sendingResetLink : s.sendResetLink,
            onPressed: controller.isLoading ? null : _handleSendResetLink,
          ),
          ResponsiveGap(24),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: r.bodyStyle(color: theme.mutedText),
              children: [
                TextSpan(text: s.rememberedPassword),
                TextSpan(
                  text: s.login,
                  recognizer: TapGestureRecognizer()..onTap = _goToLogin,
                  style: TextStyle(
                    color: theme.linkAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
