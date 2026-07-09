import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_responsive.dart';
import '../../../config/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import 'login_controller.dart';
import '../../../routes/app_routes.dart';
import '../../../services/push_notification_service.dart';
import '../../../utils/driver_auth_navigation.dart';
import '../widgets/auth_top_toast.dart';
import '../widgets/auth_widgets.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/qglide_pulse_loader.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView>
    with AuthValidationToastState {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSocialAuthenticating = false;

  bool get _supportsAppleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  LoginController get _controller => ref.read(loginControllerProvider);

  Future<void> _handleLogin() async {
    try {
      final response = await _controller.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;

      if (response == null) {
        presentAuthValidationError(_controller.errorMessage);
        return;
      }

      final data = response['data'];
      final warning = data is Map ? data['warning'] as String? : null;
      if (warning != null && warning.isNotEmpty) {
        AuthTopToast.showWarning(context, warning);
      }

      unawaited(PushNotificationService.registerTokenIfLoggedIn());

      await DriverAuthNavigation.navigateAfterAuth(
        context,
        loginResponse: response,
      );
    } catch (error) {
      if (!mounted) return;
      AuthTopToast.showError(
        context,
        AppStringsScope.of(context).signInFailed,
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final response = await _controller.signInWithGoogle(
      onAccountSelected: () {
        if (mounted) setState(() => _isSocialAuthenticating = true);
      },
    );
    if (!mounted) return;

    if (response == null) {
      setState(() => _isSocialAuthenticating = false);
      return;
    }

    unawaited(PushNotificationService.registerTokenIfLoggedIn());

    await DriverAuthNavigation.navigateAfterAuth(
      context,
      loginResponse: response,
    );

    if (mounted) setState(() => _isSocialAuthenticating = false);
  }

  Future<void> _handleAppleSignIn() async {
    if (mounted) setState(() => _isSocialAuthenticating = true);

    final response = await _controller.signInWithApple();
    if (!mounted) return;

    if (response == null) {
      setState(() => _isSocialAuthenticating = false);
      return;
    }

    unawaited(PushNotificationService.registerTokenIfLoggedIn());

    await DriverAuthNavigation.navigateAfterAuth(
      context,
      loginResponse: response,
    );

    if (mounted) setState(() => _isSocialAuthenticating = false);
  }

  void _goToSignup() {
    Navigator.of(context).pushNamed(AppRoutes.signup);
  }

  void _goToForgotPassword() {
    Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(loginControllerProvider);
    presentAuthValidationError(controller.errorMessage);
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ResponsiveScreenShell(
      backgroundAsset: theme.primaryAuthBackgroundAsset,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Center(
            child: AppLogo(height: r.logoHeight),
          ),
          ResponsiveGap(40),
          Text(
            s.loginTitle,
            textAlign: TextAlign.center,
            style: r.titleStyle(color: onSurface),
          ),
          ResponsiveGap(12),
          Text(
            s.loginSubtitle,
            textAlign: TextAlign.center,
            style: r.subtitleStyle(color: theme.mutedText),
          ),
          ResponsiveGap(32),
          AuthTextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            hintText: s.emailAddress,
            prefix: Icon(
              Icons.email_outlined,
              size: r.iconSm,
              color: theme.iconMuted,
            ),
          ),
          ResponsiveGap(16),
          AuthTextField(
            controller: _passwordController,
            hintText: s.enterPassword,
            obscureText: controller.obscurePassword,
            prefix: Icon(
              Icons.lock_outline,
              size: r.iconSm,
              color: theme.iconMuted,
            ),
            suffix: IconButton(
              onPressed: controller.togglePasswordVisibility,
              icon: Icon(
                controller.obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: r.iconSm,
                color: theme.iconMuted,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _goToForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: theme.linkAccent,
                padding: EdgeInsets.symmetric(vertical: r.gap(8)),
              ),
              child: Text(
                s.forgottenPassword,
                style: TextStyle(
                  fontSize: r.captionSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          ResponsiveGap(8),
          AuthPrimaryButton(
            label: controller.isLoading ? s.signingIn : s.login,
            onPressed: controller.isLoading
                ? null
                : () => unawaited(_handleLogin()),
          ),
          ResponsiveGap(24),
          const AuthOrDivider(),
          ResponsiveGap(24),
          if (_supportsAppleSignIn) ...[
            AuthAppleButton(
              onPressed: controller.isLoading
                  ? null
                  : () => unawaited(_handleAppleSignIn()),
            ),
            ResponsiveGap(12),
          ],
          AuthGoogleButton(
            onPressed: controller.isLoading
                ? null
                : () => unawaited(_handleGoogleSignIn()),
          ),
          ResponsiveGap(28),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: r.bodyStyle(color: theme.mutedText),
              children: [
                TextSpan(text: s.dontHaveAccount),
                TextSpan(
                  text: s.signUp,
                  recognizer: TapGestureRecognizer()..onTap = _goToSignup,
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
          if (_isSocialAuthenticating)
            AuthGoogleLoadingOverlay(loaderSize: r.logoHeight),
        ],
      ),
    );
  }
}
