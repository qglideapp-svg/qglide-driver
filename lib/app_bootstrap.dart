import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_navigator_key.dart';
import 'routes/app_routes.dart';
import 'services/auth_service.dart';
import 'services/driver_online_foreground_service.dart';
import 'services/push_notification_service.dart';
import 'services/splash_service.dart';
import 'utils/driver_navigation_target.dart';
import 'features/splash/splash_video_model.dart';

/// Tracks whether startup has navigated away from the splash route.
class StartupNavigationTracker {
  StartupNavigationTracker._();

  static var hasLeftSplash = false;

  static void markNavigated() => hasLeftSplash = true;
}

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  Timer? _watchdogTimer;
  var _bootstrapStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_bootstrapStarted) return;
      _bootstrapStarted = true;
      unawaited(_runBootstrap());
    });
    _watchdogTimer = Timer(const Duration(seconds: 12), () {
      unawaited(_forceNavigationIfStuck());
    });
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    super.dispose();
  }

  void _logPhase(String phase) {
    if (kDebugMode) {
      debugPrint('[Startup] $phase');
    }
  }

  Future<void> _runBootstrap() async {
    _logPhase('bootstrap_start');

    if (!kIsWeb) {
      try {
        await Firebase.initializeApp().timeout(const Duration(seconds: 10));
        _logPhase('firebase_ready');
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (error, stackTrace) {
        _logPhase('firebase_failed: $error');
        if (kDebugMode) {
          debugPrint('$stackTrace');
        }
      }

      try {
        await PushNotificationService.captureLaunchPayloadIfNeeded().timeout(
          const Duration(seconds: 5),
        );
        await PushNotificationService.clearStaleNotificationActionsOnNormalLaunch();
        _logPhase('notification_capture_ready');
      } catch (error, stackTrace) {
        _logPhase('notification_capture_failed: $error');
        if (kDebugMode) {
          debugPrint('$stackTrace');
        }
      }
    }

    try {
      await AuthService.maintainSession();
      _logPhase('session_restored');
    } catch (error) {
      _logPhase('session_restore_failed: $error');
    }

    if (!kIsWeb) {
      try {
        await DriverOnlineForegroundService.init();
        await PushNotificationService.initialize();
        _logPhase('deferred_services_ready');
      } catch (error, stackTrace) {
        _logPhase('deferred_services_failed: $error');
        if (kDebugMode) {
          debugPrint('$stackTrace');
        }
      }
    }

    _logPhase('bootstrap_complete');
    await _handleNotificationColdStart();
  }

  Future<void> _handleNotificationColdStart() async {
    if (StartupNavigationTracker.hasLeftSplash) return;
    if (!PushNotificationService.shouldOpenHomeForRideLaunch) return;
    if (!AuthService.hasValidSession) return;

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    _logPhase('notification_cold_start_redirect');
    await SplashVideoModel.stopAndDispose();
    StartupNavigationTracker.markNavigated();
    await nav.pushReplacementNamed(AppRoutes.home);
    if (AuthService.hasValidSession) {
      unawaited(PushNotificationService.registerTokenIfLoggedIn());
    }
    _logPhase('navigated');
  }

  Future<void> _forceNavigationIfStuck() async {
    if (StartupNavigationTracker.hasLeftSplash) return;
    // First-time users should finish the splash video; splash has its own fallback.
    if (!SplashService.hasSeenSplashVideo) return;

    _logPhase('watchdog_force_navigation');

    final DriverNavigationTarget target;
    if (AuthService.hasValidSession) {
      target = const DriverNavigationTarget(route: AppRoutes.home);
    } else {
      target = DriverNavigationTarget(
        route: AuthService.unauthenticatedEntryRoute,
      );
    }

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    await SplashVideoModel.stopAndDispose();
    StartupNavigationTracker.markNavigated();
    try {
      await nav.pushReplacementNamed(
        target.route,
        arguments: target.arguments,
      );
    } catch (_) {
      await nav.pushReplacementNamed(AppRoutes.login);
    }
    _logPhase('navigated');
  }

  @override
  Widget build(BuildContext context) {
    return const App();
  }
}
