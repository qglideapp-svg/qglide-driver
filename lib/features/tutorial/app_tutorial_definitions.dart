import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../routes/app_routes.dart';

class AppTutorialStepDefinition {
  const AppTutorialStepDefinition({
    required this.id,
    required this.titleKey,
    required this.bodyKey,
    this.align = ContentAlign.bottom,
    this.shape = ShapeLightFocus.RRect,
    this.radius = 12,
  });

  final String id;
  final String titleKey;
  final String bodyKey;
  final ContentAlign align;
  final ShapeLightFocus shape;
  final double radius;
}

class AppTutorialDefinitions {
  AppTutorialDefinitions._();

  static const signupSteps = [
    AppTutorialStepDefinition(
      id: 'signup_form',
      titleKey: 'tutorialSignupFormTitle',
      bodyKey: 'tutorialSignupFormBody',
    ),
    AppTutorialStepDefinition(
      id: 'signup_create_account',
      titleKey: 'tutorialSignupCreateTitle',
      bodyKey: 'tutorialSignupCreateBody',
      align: ContentAlign.top,
    ),
    AppTutorialStepDefinition(
      id: 'signup_social',
      titleKey: 'tutorialSignupSocialTitle',
      bodyKey: 'tutorialSignupSocialBody',
      align: ContentAlign.top,
    ),
    AppTutorialStepDefinition(
      id: 'signup_login_link',
      titleKey: 'tutorialSignupLoginLinkTitle',
      bodyKey: 'tutorialSignupLoginLinkBody',
      align: ContentAlign.top,
    ),
  ];

  static const verificationSteps = [
    AppTutorialStepDefinition(
      id: 'verification_otp',
      titleKey: 'tutorialVerificationOtpTitle',
      bodyKey: 'tutorialVerificationOtpBody',
    ),
    AppTutorialStepDefinition(
      id: 'verification_resend',
      titleKey: 'tutorialVerificationResendTitle',
      bodyKey: 'tutorialVerificationResendBody',
      align: ContentAlign.top,
    ),
  ];

  static const documentUploadSteps = [
    AppTutorialStepDefinition(
      id: 'documents_progress',
      titleKey: 'tutorialDocumentsProgressTitle',
      bodyKey: 'tutorialDocumentsProgressBody',
    ),
    AppTutorialStepDefinition(
      id: 'documents_card',
      titleKey: 'tutorialDocumentsCardTitle',
      bodyKey: 'tutorialDocumentsCardBody',
    ),
    AppTutorialStepDefinition(
      id: 'documents_next',
      titleKey: 'tutorialDocumentsNextTitle',
      bodyKey: 'tutorialDocumentsNextBody',
      align: ContentAlign.top,
    ),
  ];

  static const manageVehicleSteps = [
    AppTutorialStepDefinition(
      id: 'vehicle_photo',
      titleKey: 'tutorialVehiclePhotoTitle',
      bodyKey: 'tutorialVehiclePhotoBody',
    ),
    AppTutorialStepDefinition(
      id: 'vehicle_fields',
      titleKey: 'tutorialVehicleFieldsTitle',
      bodyKey: 'tutorialVehicleFieldsBody',
    ),
    AppTutorialStepDefinition(
      id: 'vehicle_submit',
      titleKey: 'tutorialVehicleSubmitTitle',
      bodyKey: 'tutorialVehicleSubmitBody',
      align: ContentAlign.top,
    ),
  ];

  static const pendingApprovalSteps = [
    AppTutorialStepDefinition(
      id: 'pending_review',
      titleKey: 'tutorialPendingReviewTitle',
      bodyKey: 'tutorialPendingReviewBody',
    ),
    AppTutorialStepDefinition(
      id: 'pending_login',
      titleKey: 'tutorialPendingLoginTitle',
      bodyKey: 'tutorialPendingLoginBody',
      align: ContentAlign.top,
    ),
  ];

  static const loginSteps = [
    AppTutorialStepDefinition(
      id: 'login_button',
      titleKey: 'tutorialLoginButtonTitle',
      bodyKey: 'tutorialLoginButtonBody',
      align: ContentAlign.top,
    ),
    AppTutorialStepDefinition(
      id: 'login_forgot',
      titleKey: 'tutorialLoginForgotTitle',
      bodyKey: 'tutorialLoginForgotBody',
    ),
    AppTutorialStepDefinition(
      id: 'login_signup_link',
      titleKey: 'tutorialLoginSignupTitle',
      bodyKey: 'tutorialLoginSignupBody',
      align: ContentAlign.top,
    ),
  ];

  static const homeSteps = [
    AppTutorialStepDefinition(
      id: 'home_profile',
      titleKey: 'tutorialHomeProfileTitle',
      bodyKey: 'tutorialHomeProfileBody',
      shape: ShapeLightFocus.Circle,
    ),
    AppTutorialStepDefinition(
      id: 'home_notifications',
      titleKey: 'tutorialHomeNotificationsTitle',
      bodyKey: 'tutorialHomeNotificationsBody',
      shape: ShapeLightFocus.Circle,
    ),
    AppTutorialStepDefinition(
      id: 'home_go_online',
      titleKey: 'tutorialHomeGoOnlineTitle',
      bodyKey: 'tutorialHomeGoOnlineBody',
      align: ContentAlign.top,
    ),
    AppTutorialStepDefinition(
      id: 'home_earnings_tab',
      titleKey: 'tutorialHomeEarningsTitle',
      bodyKey: 'tutorialHomeEarningsBody',
    ),
    AppTutorialStepDefinition(
      id: 'home_location',
      titleKey: 'tutorialHomeLocationTitle',
      bodyKey: 'tutorialHomeLocationBody',
      shape: ShapeLightFocus.Circle,
      align: ContentAlign.top,
    ),
    AppTutorialStepDefinition(
      id: 'home_dashboard',
      titleKey: 'tutorialHomeDashboardTitle',
      bodyKey: 'tutorialHomeDashboardBody',
      align: ContentAlign.top,
    ),
  ];

  static List<AppTutorialStepDefinition> stepsForRoute(String route) {
    switch (route) {
      case AppRoutes.signup:
        return signupSteps;
      case AppRoutes.verification:
        return const [];
      case AppRoutes.documentUpload:
        return documentUploadSteps;
      case AppRoutes.manageVehicle:
        return manageVehicleSteps;
      case AppRoutes.documentSubmissionSuccess:
        return pendingApprovalSteps;
      case AppRoutes.login:
        return loginSteps;
      case AppRoutes.home:
        return homeSteps;
      default:
        return const [];
    }
  }
}
