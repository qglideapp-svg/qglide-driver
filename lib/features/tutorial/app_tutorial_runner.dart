import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../config/app_strings.dart';
import '../../routes/app_routes.dart';
import '../../services/app_tutorial_service.dart';
import '../../shared/widgets/app_strings_scope.dart';
import 'app_tutorial_definitions.dart';
import 'tutorial_target_registry.dart';

/// Shows and controls the in-app coach-mark walkthrough for a screen.
class AppTutorialRunner {
  AppTutorialRunner._();

  static TutorialCoachMark? _activeCoachMark;
  static String? _activeRoute;
  static var _isShowing = false;

  static bool get isShowing => _isShowing;

  static Future<void> maybeShowForRoute({
    required BuildContext context,
    required String route,
    required TutorialTargetRegistry registry,
    Duration delay = const Duration(milliseconds: 450),
  }) async {
    await AppTutorialService.loadFromDisk();
    if (!context.mounted) return;
    if (!AppTutorialService.shouldShowForRoute(route)) return;
    if (_isShowing && _activeRoute == route) return;

    final steps = AppTutorialDefinitions.stepsForRoute(route);
    if (steps.isEmpty) return;

    await Future<void>.delayed(delay);
    if (!context.mounted) return;
    if (!AppTutorialService.shouldShowForRoute(route)) return;

    final hasMissingTarget = steps.any(
      (step) => registry.tryKey(step.id)?.currentContext == null,
    );
    if (hasMissingTarget) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!context.mounted) return;
    }

    final startIndex = AppTutorialService.stepIndexForRoute(route).clamp(
      0,
      steps.length - 1,
    );

    _show(
      context: context,
      route: route,
      registry: registry,
      initialFocus: startIndex,
    );
  }

  static void _show({
    required BuildContext context,
    required String route,
    required TutorialTargetRegistry registry,
    required int initialFocus,
  }) {
    if (!context.mounted) return;

    final strings = AppStringsScope.of(context);
    final steps = AppTutorialDefinitions.stepsForRoute(route);
    if (steps.isEmpty) return;

    _finishSilently();

    var currentIndex = initialFocus;
    TutorialCoachMark? coachMark;

    void handleNext() {
      final mark = coachMark;
      if (mark == null) return;

      if (currentIndex >= steps.length - 1) {
        mark.finish();
        return;
      }

      currentIndex += 1;
      unawaited(AppTutorialService.setStepIndexForRoute(route, currentIndex));
      mark.next();
    }

    void handleSkip() {
      unawaited(_handleSkip());
    }

    final bottomInset = _tooltipBottomInset(context, route);

    coachMark = TutorialCoachMark(
      useSafeArea: true,
      beforeFocus: (target) async {
        final id = target.identify?.toString();
        if (id == null || id.isEmpty) return;

        final targetContext = registry.tryKey(id)?.currentContext;
        if (targetContext == null || !targetContext.mounted) return;

        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: 0.35,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      targets: [
        for (var i = 0; i < steps.length; i++)
          TargetFocus(
            identify: steps[i].id,
            keyTarget: registry.keyFor(steps[i].id),
            shape: steps[i].shape,
            radius: steps[i].radius,
            enableOverlayTab: false,
            enableTargetTab: false,
            contents: [
              TargetContent(
                align: ContentAlign.custom,
                padding: EdgeInsets.zero,
                customPosition: CustomTargetContentPosition(
                  left: 16,
                  right: 16,
                  bottom: bottomInset,
                ),
                builder: (context, controller) {
                  return _TutorialTooltipCard(
                    strings: strings,
                    title: _resolveString(strings, steps[i].titleKey),
                    body: _resolveString(strings, steps[i].bodyKey),
                    stepIndex: i,
                    totalSteps: steps.length,
                    isLast: i == steps.length - 1,
                    onNext: handleNext,
                    onSkip: handleSkip,
                  );
                },
              ),
            ],
          ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.78,
      paddingFocus: 8,
      hideSkip: true,
      pulseEnable: true,
      initialFocus: initialFocus,
      onFinish: () {
        unawaited(_handleFinished(route));
      },
    );

    _activeCoachMark = coachMark;
    _activeRoute = route;
    _isShowing = true;

    coachMark.show(context: context, rootOverlay: true);
  }

  static String _resolveString(AppStrings strings, String key) {
    switch (key) {
      case 'tutorialSignupFormTitle':
        return strings.tutorialSignupFormTitle;
      case 'tutorialSignupFormBody':
        return strings.tutorialSignupFormBody;
      case 'tutorialSignupCreateTitle':
        return strings.tutorialSignupCreateTitle;
      case 'tutorialSignupCreateBody':
        return strings.tutorialSignupCreateBody;
      case 'tutorialSignupSocialTitle':
        return strings.tutorialSignupSocialTitle;
      case 'tutorialSignupSocialBody':
        return strings.tutorialSignupSocialBody;
      case 'tutorialSignupLoginLinkTitle':
        return strings.tutorialSignupLoginLinkTitle;
      case 'tutorialSignupLoginLinkBody':
        return strings.tutorialSignupLoginLinkBody;
      case 'tutorialVerificationOtpTitle':
        return strings.tutorialVerificationOtpTitle;
      case 'tutorialVerificationOtpBody':
        return strings.tutorialVerificationOtpBody;
      case 'tutorialVerificationResendTitle':
        return strings.tutorialVerificationResendTitle;
      case 'tutorialVerificationResendBody':
        return strings.tutorialVerificationResendBody;
      case 'tutorialVerificationConfirmTitle':
        return strings.tutorialVerificationConfirmTitle;
      case 'tutorialVerificationConfirmBody':
        return strings.tutorialVerificationConfirmBody;
      case 'tutorialDocumentsProgressTitle':
        return strings.tutorialDocumentsProgressTitle;
      case 'tutorialDocumentsProgressBody':
        return strings.tutorialDocumentsProgressBody;
      case 'tutorialDocumentsCardTitle':
        return strings.tutorialDocumentsCardTitle;
      case 'tutorialDocumentsCardBody':
        return strings.tutorialDocumentsCardBody;
      case 'tutorialDocumentsNextTitle':
        return strings.tutorialDocumentsNextTitle;
      case 'tutorialDocumentsNextBody':
        return strings.tutorialDocumentsNextBody;
      case 'tutorialVehiclePhotoTitle':
        return strings.tutorialVehiclePhotoTitle;
      case 'tutorialVehiclePhotoBody':
        return strings.tutorialVehiclePhotoBody;
      case 'tutorialVehicleFieldsTitle':
        return strings.tutorialVehicleFieldsTitle;
      case 'tutorialVehicleFieldsBody':
        return strings.tutorialVehicleFieldsBody;
      case 'tutorialVehicleSubmitTitle':
        return strings.tutorialVehicleSubmitTitle;
      case 'tutorialVehicleSubmitBody':
        return strings.tutorialVehicleSubmitBody;
      case 'tutorialPendingReviewTitle':
        return strings.tutorialPendingReviewTitle;
      case 'tutorialPendingReviewBody':
        return strings.tutorialPendingReviewBody;
      case 'tutorialPendingLoginTitle':
        return strings.tutorialPendingLoginTitle;
      case 'tutorialPendingLoginBody':
        return strings.tutorialPendingLoginBody;
      case 'tutorialLoginButtonTitle':
        return strings.tutorialLoginButtonTitle;
      case 'tutorialLoginButtonBody':
        return strings.tutorialLoginButtonBody;
      case 'tutorialLoginForgotTitle':
        return strings.tutorialLoginForgotTitle;
      case 'tutorialLoginForgotBody':
        return strings.tutorialLoginForgotBody;
      case 'tutorialLoginSignupTitle':
        return strings.tutorialLoginSignupTitle;
      case 'tutorialLoginSignupBody':
        return strings.tutorialLoginSignupBody;
      case 'tutorialHomeProfileTitle':
        return strings.tutorialHomeProfileTitle;
      case 'tutorialHomeProfileBody':
        return strings.tutorialHomeProfileBody;
      case 'tutorialHomeNotificationsTitle':
        return strings.tutorialHomeNotificationsTitle;
      case 'tutorialHomeNotificationsBody':
        return strings.tutorialHomeNotificationsBody;
      case 'tutorialHomeGoOnlineTitle':
        return strings.tutorialHomeGoOnlineTitle;
      case 'tutorialHomeGoOnlineBody':
        return strings.tutorialHomeGoOnlineBody;
      case 'tutorialHomeEarningsTitle':
        return strings.tutorialHomeEarningsTitle;
      case 'tutorialHomeEarningsBody':
        return strings.tutorialHomeEarningsBody;
      case 'tutorialHomeLocationTitle':
        return strings.tutorialHomeLocationTitle;
      case 'tutorialHomeLocationBody':
        return strings.tutorialHomeLocationBody;
      case 'tutorialHomeDashboardTitle':
        return strings.tutorialHomeDashboardTitle;
      case 'tutorialHomeDashboardBody':
        return strings.tutorialHomeDashboardBody;
      default:
        return '';
    }
  }

  static Future<void> _handleFinished(String route) async {
    await AppTutorialService.clearStepIndexForRoute(route);
    await AppTutorialService.completeRouteTutorial(route);
    await AppTutorialService.clearReplayRoute();
    _activeCoachMark?.removeOverlayEntry();
    _finishSilently();
  }

  static Future<void> _handleSkip() async {
    await AppTutorialService.markSkipped();
    _activeCoachMark?.removeOverlayEntry();
    _finishSilently();
  }

  static void _finishSilently() {
    _isShowing = false;
    _activeRoute = null;
    _activeCoachMark = null;
  }

  static void dismissIfShowing() {
    _activeCoachMark?.removeOverlayEntry();
    _finishSilently();
  }

  static double _tooltipBottomInset(BuildContext context, String route) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    var inset = viewPadding.bottom + 16;

    if (route == AppRoutes.home) {
      inset += screenHeight * 0.26;
    }

    return inset;
  }
}

class _TutorialTooltipCard extends StatelessWidget {
  const _TutorialTooltipCard({
    required this.strings,
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.totalSteps,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final AppStrings strings;
  final String title;
  final String body;
  final int stepIndex;
  final int totalSteps;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black;
    final bodyColor = isDark ? Colors.white70 : Colors.black54;
    final maxTooltipHeight = MediaQuery.sizeOf(context).height * 0.38;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxTooltipHeight),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE3AA00).withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.tutorialStepCounter(stepIndex + 1, totalSteps),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: bodyColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: bodyColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: bodyColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(strings.tutorialSkipTour),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE3AA00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(isLast ? strings.tutorialGotIt : strings.next),
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
