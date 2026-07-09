import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../services/app_locale_service.dart';
import '../../features/auth/document_upload/document_upload_controller.dart';
import '../../features/auth/forgot_password/forgot_password_controller.dart';
import '../../features/auth/login/login_controller.dart';
import '../../features/auth/signup/signup_controller.dart';
import '../../features/auth/verification/verification_args.dart';
import '../../features/auth/verification/verification_controller.dart';
import '../../features/home/home_controller.dart';
import '../../features/onboarding/onboarding_controller.dart';
import '../../features/splash/splash_controller.dart';

T _createNotifier<T extends ChangeNotifier>(
  Ref ref,
  T Function() create,
) {
  return create();
}

final splashControllerProvider = ChangeNotifierProvider<SplashController>(
  (ref) => _createNotifier(ref, SplashController.new),
);

final onboardingControllerProvider =
    ChangeNotifierProvider.autoDispose<OnboardingController>(
  (ref) => _createNotifier(ref, OnboardingController.new),
);

final loginControllerProvider =
    ChangeNotifierProvider.autoDispose<LoginController>(
  (ref) => _createNotifier(ref, LoginController.new),
);

final signupControllerProvider =
    ChangeNotifierProvider.autoDispose<SignupController>(
  (ref) => _createNotifier(ref, SignupController.new),
);

final forgotPasswordControllerProvider =
    ChangeNotifierProvider.autoDispose<ForgotPasswordController>(
  (ref) => _createNotifier(ref, ForgotPasswordController.new),
);

final verificationControllerProvider = ChangeNotifierProvider.autoDispose
    .family<VerificationController, String>(
  (ref, cacheKey) {
    final args = VerificationArgs.parseCacheKey(cacheKey);
    return _createNotifier(
      ref,
      () => VerificationController(
        phoneNumber: args?.phoneNumber ?? '',
        normalizedPhone: args?.normalizedPhone ?? '',
        email: args?.email,
      ),
    );
  },
);

final documentUploadControllerProvider =
    ChangeNotifierProvider.autoDispose<DocumentUploadController>(
  (ref) => _createNotifier(ref, DocumentUploadController.new),
);

final homeControllerProvider = ChangeNotifierProvider<HomeController>(
  (ref) => _createNotifier(ref, HomeController.new),
);

class LocaleNotifier extends Notifier<bool> {
  @override
  bool build() => AppLocaleService.instance.isArabic;

  Future<void> setArabic(bool value) async {
    await AppLocaleService.instance.setArabic(value);
    state = value;
  }

  Future<void> setEnglish() => setArabic(false);

  Future<void> toggle() => setArabic(!state);
}

final localeProvider = NotifierProvider<LocaleNotifier, bool>(LocaleNotifier.new);
