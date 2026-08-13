import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_responsive.dart';
import '../../../config/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import 'signup_controller.dart';
import 'signup_phone_confirmation_modal.dart';
import 'password_requirements.dart';
import 'password_requirements_checklist.dart';
import '../verification/verification_args.dart';
import '../../../routes/app_routes.dart';
import '../../../features/tutorial/tutorial_screen_helper.dart';
import '../../../features/tutorial/tutorial_target.dart';
import '../../../features/tutorial/tutorial_target_registry.dart';
import '../../../services/push_notification_service.dart';
import '../../../features/splash/splash_video_model.dart';
import '../widgets/auth_top_toast.dart';
import '../widgets/auth_widgets.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/in_app_web_view.dart';
import '../../../shared/widgets/qglide_pulse_loader.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';

class SignupView extends ConsumerStatefulWidget {
  const SignupView({super.key});

  @override
  ConsumerState<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends ConsumerState<SignupView>
    with AuthValidationToastState {
  final _tutorialRegistry = TutorialTargetRegistry();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralController = TextEditingController();
  var _isSocialAuthenticating = false;
  var _oauthEmailLocked = false;
  TapGestureRecognizer? _termsRecognizer;
  TapGestureRecognizer? _privacyRecognizer;

  bool get _supportsAppleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static const _termsUrl = 'https://qglide.com/terms-and-conditions/';
  static const _privacyUrl = 'https://qglide.com/privacy-policy/';

  SignupController get _controller => ref.read(signupControllerProvider);

  Future<void> _applyOAuthPrefill(Map<String, dynamic> response) async {
    final prefill = response['prefill'];
    if (prefill is! Map<String, dynamic>) return;

    final fullName = prefill['full_name']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) {
      _fullNameController.text = fullName;
    }

    final email = prefill['email']?.toString().trim();
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
      _oauthEmailLocked = true;
    }

    final phone = prefill['phone']?.toString().trim();
    if (phone != null && phone.isNotEmpty) {
      _phoneController.text = phone;
    }

    if (!mounted) return;
    setState(() {});
    AuthTopToast.showSuccess(
      context,
      AppStringsScope.of(context).signedInCompleteDetails,
    );
  }

  void _ensureRecognizers() {
    _termsRecognizer ??= TapGestureRecognizer()..onTap = _openTerms;
    _privacyRecognizer ??= TapGestureRecognizer()..onTap = _openPrivacyPolicy;
  }

  void _openTerms() {
    final s = AppStringsScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InAppWebView(
          url: _termsUrl,
          title: s.termsAndConditions,
        ),
      ),
    );
  }

  void _openPrivacyPolicy() {
    final s = AppStringsScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InAppWebView(
          url: _privacyUrl,
          title: s.privacyPolicyTitle,
        ),
      ),
    );
  }

  Future<void> _handleCreateAccount() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) return;

    final confirmed = await SignupPhoneConfirmationModal.show(
      context,
      phoneNumber: phoneNumber,
    );
    if (!confirmed || !mounted) return;

    await _submitCreateAccount();
  }

  Future<void> _submitCreateAccount() async {
    final Map<String, dynamic>? response;
    if (_controller.isOAuthSignupPending) {
      response = await _controller.completeOAuthSignup(
        fullName: _fullNameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        referralCode: _referralController.text,
      );
    } else {
      response = await _controller.signUp(
        fullName: _fullNameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        referralCode: _referralController.text,
      );
    }
    if (!mounted || response == null) return;

    final data = response['data'];
    final message = data is Map ? data['message'] as String? : null;
    if (message != null && message.isNotEmpty) {
      AuthTopToast.showSuccess(context, message);
    }

    unawaited(PushNotificationService.registerTokenIfLoggedIn());

    Navigator.of(context).pushReplacementNamed(
      AppRoutes.verification,
      arguments: VerificationArgs.fromPhone(
        phone: _phoneController.text,
        email: _emailController.text.trim(),
      ),
    );
  }

  Future<void> _handleGoogleSignUp() async {
    unawaited(SplashVideoModel.suppressIntro());
    final response = await _controller.signInWithGoogle(
      onAccountSelected: () {
        unawaited(SplashVideoModel.suppressIntro());
        if (mounted) setState(() => _isSocialAuthenticating = true);
      },
    );
    if (!mounted) return;

    if (response == null) {
      setState(() => _isSocialAuthenticating = false);
      return;
    }

    await _applyOAuthPrefill(response);

    if (mounted) setState(() => _isSocialAuthenticating = false);
  }

  Future<void> _handleAppleSignUp() async {
    unawaited(SplashVideoModel.suppressIntro());
    if (mounted) setState(() => _isSocialAuthenticating = true);

    final response = await _controller.signInWithApple();
    if (!mounted) return;

    if (response == null) {
      setState(() => _isSocialAuthenticating = false);
      return;
    }

    await _applyOAuthPrefill(response);

    if (mounted) setState(() => _isSocialAuthenticating = false);
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
  void initState() {
    super.initState();
    unawaited(SplashVideoModel.suppressIntro());
    _fullNameController.addListener(_onFormFieldsChanged);
    _emailController.addListener(_onFormFieldsChanged);
    _phoneController.addListener(_onFormFieldsChanged);
    _passwordController.addListener(_onFormFieldsChanged);
    _confirmPasswordController.addListener(_onFormFieldsChanged);
    scheduleTutorialForRoute(
      state: this,
      route: AppRoutes.signup,
      registry: _tutorialRegistry,
    );
  }

  void _onFormFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fullNameController.removeListener(_onFormFieldsChanged);
    _emailController.removeListener(_onFormFieldsChanged);
    _phoneController.removeListener(_onFormFieldsChanged);
    _passwordController.removeListener(_onFormFieldsChanged);
    _confirmPasswordController.removeListener(_onFormFieldsChanged);
    _termsRecognizer?.dispose();
    _privacyRecognizer?.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureRecognizers();
    final controller = ref.watch(signupControllerProvider);
    presentAuthValidationError(controller.errorMessage);
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final passwordRequirements = PasswordRequirements.evaluate(password);
    final showPasswordChecks = password.isNotEmpty;
    final showConfirmMatch = confirmPassword.isNotEmpty;
    final isOAuthSignup = controller.isOAuthSignupPending;
    final canCreateAccount = isOAuthSignup
        ? !controller.isLoading &&
            _fullNameController.text.trim().isNotEmpty &&
            _emailController.text.trim().isNotEmpty &&
            _phoneController.text.trim().isNotEmpty
        : !controller.isLoading &&
            passwordRequirements.isMet &&
            password == confirmPassword &&
            password.isNotEmpty &&
            confirmPassword.isNotEmpty;

    return ResponsiveScreenShell(
      backgroundAsset: theme.formAuthBackgroundAsset,
      padding: r.signupTopPadding,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          ResponsiveGap(24),
          Text(
            s.createDriverAccount,
            style: r.titleStyle(color: onSurface),
          ),
          ResponsiveGap(8),
          Text(
            s.signupSubtitle,
            style: r.subtitleStyle(color: theme.mutedText),
          ),
          ResponsiveGap(28),
          TutorialTarget(
            registry: _tutorialRegistry,
            id: 'signup_form',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          AuthTextField(
            controller: _fullNameController,
            hintText: s.fullName,
            prefix: Icon(Icons.person_outline, size: r.iconSm, color: theme.iconMuted),
          ),
          ResponsiveGap(16),
          AuthTextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            hintText: s.emailAddress,
            readOnly: _oauthEmailLocked,
            prefix: Icon(Icons.email_outlined, size: r.iconSm, color: theme.iconMuted),
          ),
          ResponsiveGap(16),
          AuthTextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            hintText: s.phoneNumber,
            prefix: const PhonePrefix(),
          ),
          if (!isOAuthSignup) ...[
          ResponsiveGap(16),
          AuthTextField(
            controller: _passwordController,
            hintText: s.enterPassword,
            obscureText: _controller.obscurePassword,
            prefix: Icon(Icons.lock_outline, size: r.iconSm, color: theme.iconMuted),
            suffix: IconButton(
              onPressed: _controller.togglePasswordVisibility,
              icon: Icon(
                _controller.obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: r.iconSm,
                color: theme.iconMuted,
              ),
            ),
          ),
          if (showPasswordChecks) ...[
            ResponsiveGap(10),
            PasswordRequirementsChecklist(
              requirements: passwordRequirements,
              showConfirmMatch: showConfirmMatch,
              passwordsMatch: password == confirmPassword,
            ),
          ],
          ResponsiveGap(16),
          AuthTextField(
            controller: _confirmPasswordController,
            hintText: s.confirmPassword,
            obscureText: _controller.obscureConfirmPassword,
            prefix: Icon(Icons.lock_outline, size: r.iconSm, color: theme.iconMuted),
            suffix: IconButton(
              onPressed: _controller.toggleConfirmPasswordVisibility,
              icon: Icon(
                _controller.obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: r.iconSm,
                color: theme.iconMuted,
              ),
            ),
          ),
          ],
          ResponsiveGap(16),
          AuthTextField(
            controller: _referralController,
            hintText: s.referralCodeOptional,
            prefix: Icon(Icons.local_offer_outlined, size: r.iconSm, color: theme.iconMuted),
          ),
              ],
            ),
          ),
          ResponsiveGap(24),
          TutorialTarget(
            registry: _tutorialRegistry,
            id: 'signup_create_account',
            child: AuthPrimaryButton(
            label: controller.isLoading ? s.creatingAccount : s.createAccount,
            onPressed: canCreateAccount ? _handleCreateAccount : null,
            ),
          ),
          ResponsiveGap(16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: r.captionStyle(color: theme.mutedText),
              children: [
                TextSpan(text: s.agreeToTermsPrefix),
                TextSpan(
                  text: s.terms,
                  recognizer: _termsRecognizer,
                  style: TextStyle(color: theme.linkAccent, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: s.agreeToTermsAnd),
                TextSpan(
                  text: s.privacyPolicy,
                  recognizer: _privacyRecognizer,
                  style: TextStyle(color: theme.linkAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ResponsiveGap(24),
          const AuthOrDivider(),
          ResponsiveGap(24),
          if (_supportsAppleSignIn)
            TutorialTarget(
              registry: _tutorialRegistry,
              id: 'signup_social',
              child: Row(
              children: [
                Expanded(
                  child: AuthSocialButton(
                    label: s.google,
                    backgroundColor: theme.socialButtonBackground,
                    foregroundColor: onSurface,
                    icon: GoogleLogoIcon(size: r.iconSm),
                    onPressed: controller.isLoading || isOAuthSignup
                        ? null
                        : () => unawaited(_handleGoogleSignUp()),
                    expanded: false,
                  ),
                ),
                ResponsiveHGap(12),
                Expanded(
                  child: AuthSocialButton(
                    label: s.apple,
                    backgroundColor: theme.socialButtonBackground,
                    foregroundColor: onSurface,
                    icon: Icon(Icons.apple, size: r.iconSm),
                    onPressed: controller.isLoading || isOAuthSignup
                        ? null
                        : () => unawaited(_handleAppleSignUp()),
                    expanded: false,
                  ),
                ),
              ],
            ),
            )
          else
            TutorialTarget(
              registry: _tutorialRegistry,
              id: 'signup_social',
              child: AuthSocialButton(
              label: s.google,
              backgroundColor: theme.socialButtonBackground,
              foregroundColor: onSurface,
              icon: GoogleLogoIcon(size: r.iconSm),
              onPressed: controller.isLoading || isOAuthSignup
                  ? null
                  : () => unawaited(_handleGoogleSignUp()),
            ),
            ),
          ResponsiveGap(28),
          TutorialTarget(
            registry: _tutorialRegistry,
            id: 'signup_login_link',
            child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: r.bodyStyle(color: theme.mutedText),
              children: [
                TextSpan(text: s.alreadyHaveAccount),
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
