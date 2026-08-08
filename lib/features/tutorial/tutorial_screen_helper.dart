import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/app_tutorial_service.dart';
import 'app_tutorial_runner.dart';
import 'tutorial_target_registry.dart';

void scheduleTutorialForRoute({
  required State state,
  required String route,
  required TutorialTargetRegistry registry,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!state.mounted) return;
    unawaited(
      AppTutorialRunner.maybeShowForRoute(
        context: state.context,
        route: route,
        registry: registry,
      ),
    );
  });
}

/// Re-triggers the walkthrough after the current frame, e.g. after navigation.
void scheduleTutorialReplayForRoute({
  required BuildContext context,
  required String route,
  required TutorialTargetRegistry registry,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    unawaited(
      AppTutorialRunner.maybeShowForRoute(
        context: context,
        route: route,
        registry: registry,
        delay: const Duration(milliseconds: 600),
      ),
    );
  });
}

bool isTutorialAuthRoute(String route) {
  return AppTutorialService.authRouteOrder.contains(route);
}
