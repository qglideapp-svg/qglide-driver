import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app_bootstrap.dart';
import '../../core/providers/app_providers.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../utils/driver_auth_navigation.dart';
import '../../utils/driver_navigation_target.dart';
import '../../services/push_notification_service.dart';
import '../../services/splash_service.dart';
import '../auth/widgets/auth_widgets.dart';
import 'splash_controller.dart';
import 'splash_video_model.dart';

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

  bool get _shouldSkipIntroVideo =>
      AuthService.hasValidSession || SplashService.hasSeenSplashVideo;

  @override
  void initState() {
    super.initState();
    _navigationTargetFuture = _resolveNavigationTarget();

    if (_shouldSkipIntroVideo) {
      unawaited(SplashVideoModel.stopAndDispose());
      unawaited(
        _navigationTargetFuture!.then((_) {
          if (mounted && !_hasNavigated) {
            _scheduleNavigation();
          }
        }),
      );
      _startupFallbackTimer = Timer(
        Duration(seconds: AuthService.hasValidSession ? 4 : 8),
        () {
          if (!mounted || _hasNavigated) return;
          _scheduleNavigation();
        },
      );
      return;
    }

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
    await AuthService.loadStoredSessionFromDisk();
    await AuthService.maintainSession();

    if (_shouldSkipIntroVideo) {
      final fastTarget =
          await DriverAuthNavigation.resolveFastReturningSplashTarget();
      if (fastTarget != null) {
        return fastTarget;
      }
    }

    try {
      return await DriverAuthNavigation.resolveSplashTarget().timeout(
        Duration(seconds: AuthService.hasValidSession ? 3 : 8),
        onTimeout: () {
          if (AuthService.hasValidSession) {
            return const DriverNavigationTarget(route: AppRoutes.home);
          }
          return DriverNavigationTarget(
            route: AuthService.unauthenticatedEntryRoute,
          );
        },
      );
    } catch (_) {
      if (AuthService.hasValidSession) {
        return const DriverNavigationTarget(route: AppRoutes.home);
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
    if (_shouldSkipIntroVideo) {
      await SplashVideoModel.stopAndDispose();
      if (AuthService.hasValidSession) {
        await SplashService.markSplashVideoSeen();
      }
    } else if (!SplashService.hasSeenSplashVideo) {
      final splashController = ref.read(splashControllerProvider);
      await splashController.stopPlayback();
      await SplashVideoModel.stopAndDispose();
      await SplashService.markSplashVideoSeen();
    }

    DriverNavigationTarget target;
    if (PushNotificationService.shouldOpenHomeForRideLaunch &&
        AuthService.hasValidSession) {
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

    if (AuthService.hasValidSession) {
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
    if (_shouldSkipIntroVideo) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _SplashBrandLoader(),
      );
    }

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
          if (!controller.isVideoReady || controller.isComplete)
            const _SplashBrandLoader(),
          if (controller.hasVideoController &&
              controller.isVideoReady &&
              !controller.isComplete)
            _SplashVideoPlayer(controller: controller.videoController!),
        ],
      ),
    );
  }
}

class _SplashBrandLoader extends StatelessWidget {
  const _SplashBrandLoader();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: AppLogo(height: 120),
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
