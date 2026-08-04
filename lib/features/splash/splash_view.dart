import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app_bootstrap.dart';
import '../../config/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../utils/driver_auth_navigation.dart';
import '../../utils/driver_navigation_target.dart';
import 'splash_controller.dart';
import '../../services/push_notification_service.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  var _hasNavigated = false;
  ProviderSubscription<SplashController>? _splashSubscription;
  Future<DriverNavigationTarget>? _navigationTargetFuture;
  Timer? _startupFallbackTimer;

  @override
  void initState() {
    super.initState();
    _navigationTargetFuture = _resolveNavigationTarget();
    _startupFallbackTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _hasNavigated) return;
      _scheduleNavigation();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _splashSubscription = ref.listenManual(
        splashControllerProvider,
        (previous, next) {
          if (next.isComplete) {
            _scheduleNavigation();
          }
        },
      );

      unawaited(ref.read(splashControllerProvider).initialize());
    });
  }

  @override
  void dispose() {
    _startupFallbackTimer?.cancel();
    _splashSubscription?.close();
    super.dispose();
  }

  Future<DriverNavigationTarget> _resolveNavigationTarget() async {
    await AuthService.ensureSessionRestored();
    try {
      return await DriverAuthNavigation.resolveSplashTarget().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          if (AuthService.isLoggedIn || AuthService.hasStoredSession) {
            return DriverNavigationTarget(route: AppRoutes.home);
          }
          return DriverNavigationTarget(
            route: AuthService.unauthenticatedEntryRoute,
          );
        },
      );
    } catch (_) {
      if (AuthService.isLoggedIn || AuthService.hasStoredSession) {
        return DriverNavigationTarget(route: AppRoutes.home);
      }
      return DriverNavigationTarget(
        route: AuthService.unauthenticatedEntryRoute,
      );
    }
  }

  void _scheduleNavigation() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _startupFallbackTimer?.cancel();
    StartupNavigationTracker.markNavigated();
    unawaited(_navigateAfterSplash());
  }

  Future<void> _navigateAfterSplash() async {
    DriverNavigationTarget target;
    if (PushNotificationService.shouldOpenHomeForRideLaunch &&
        (AuthService.isLoggedIn || AuthService.hasStoredSession)) {
      await AuthService.ensureSessionRestored();
      target = const DriverNavigationTarget(route: AppRoutes.home);
    } else {
      try {
        target = await (_navigationTargetFuture ?? _resolveNavigationTarget());
      } catch (error) {
        target = DriverNavigationTarget(
          route: AuthService.unauthenticatedEntryRoute,
        );
      }
    }

    if (AuthService.isLoggedIn) {
      unawaited(PushNotificationService.registerTokenIfLoggedIn());
    }

    if (!mounted) return;

    ref.invalidate(splashControllerProvider);

    try {
      await Navigator.of(context).pushReplacementNamed(
        target.route,
        arguments: target.arguments,
      );
    } catch (error) {
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(splashControllerProvider);

    if (controller.isComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleNavigation();
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!controller.isVideoReady)
            Image.asset(
              AppConstants.splashPosterAsset,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          if (controller.hasVideoController)
            _SplashVideoPlayer(controller: controller.videoController!),
          if (controller.isComplete)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }
}

class _SplashVideoPlayer extends StatelessWidget {
  const _SplashVideoPlayer({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final width = value.size.width > 0 ? value.size.width : 1080.0;
    final height = value.size.height > 0 ? value.size.height : 1920.0;

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: width,
          height: height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
