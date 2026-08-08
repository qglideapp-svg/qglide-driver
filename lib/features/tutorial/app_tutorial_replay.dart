import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_navigator_key.dart';
import '../../routes/app_routes.dart';
import '../../services/app_tutorial_service.dart';
import '../../services/auth_service.dart';
import 'tutorial_screen_helper.dart';
import 'tutorial_target_registry.dart';

/// Starts a walkthrough replay from Help Center or profile support actions.
class AppTutorialReplay {
  AppTutorialReplay._();

  static Future<void> startFromHelpCenter(BuildContext context) async {
    await AppTutorialService.loadFromDisk();

    if (AuthService.isLoggedIn || AuthService.hasStoredSession) {
      await AppTutorialService.prepareReplay(
        route: AppRoutes.home,
        resetHomeSegment: true,
      );

      if (!context.mounted) return;

      final navigator = appNavigatorKey.currentState;
      if (navigator != null) {
        await navigator.pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => route.isFirst,
        );
      } else {
        await Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => route.isFirst,
        );
      }
      return;
    }

    await AppTutorialService.prepareReplay(
      route: AppRoutes.signup,
      resetAuthSegment: true,
    );

    if (!context.mounted) return;
    await Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.signup,
      (route) => route.isFirst,
    );
  }

  /// Called by HomeView after navigation to replay home segment.
  static void triggerHomeReplayIfPending({
    required BuildContext context,
    required TutorialTargetRegistry registry,
  }) {
    if (AppTutorialService.replayRoute != AppRoutes.home) return;
    scheduleTutorialReplayForRoute(
      context: context,
      route: AppRoutes.home,
      registry: registry,
    );
  }
}
