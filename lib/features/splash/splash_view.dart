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
  static const _returningUserMinLogoDuration = Duration(milliseconds: 900);
  static const _returningUserMaxWait = Duration(seconds: 3);

  var _hasNavigated = false;
  ProviderSubscription<SplashController>? _splashSubscription;
  Future<DriverNavigationTarget>? _navigationTargetFuture;
  Timer? _startupFallbackTimer;
  final _logoShownAt = DateTime.now();
  late final bool _showIntroVideo;

  @override
  void initState() {
    super.initState();
    _showIntroVideo = SplashService.shouldPlayIntroVideo;
    _navigationTargetFuture = _resolveNavigationTarget();

    if (!_showIntroVideo) {
      unawaited(_startReturningUserSplash());
      _startupFallbackTimer = Timer(_returningUserMaxWait, () {
        if (!mounted || _hasNavigated) return;
        _scheduleNavigation();
      });
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

  Future<void> _startReturningUserSplash() async {
    await SplashVideoModel.suppressIntro();
    await _navigateWhenReturningUserReady();
  }

  Future<void> _navigateWhenReturningUserReady() async {
    try {
      await _navigationTargetFuture;
    } catch (_) {}

    if (!mounted || _hasNavigated) return;

    final elapsed = DateTime.now().difference(_logoShownAt);
    final remaining = _returningUserMinLogoDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    if (!mounted || _hasNavigated) return;
    _scheduleNavigation();
  }

  @override
  void dispose() {
    _startupFallbackTimer?.cancel();
    _splashSubscription?.close();
    unawaited(SplashVideoModel.suppressIntro());
    super.dispose();
  }

  Future<DriverNavigationTarget> _resolveNavigationTarget() async {
    await AuthService.loadStoredSessionFromDisk();
    await AuthService.maintainSession();

    if (!_showIntroVideo) {
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
    if (!_showIntroVideo) {
      await SplashVideoModel.suppressIntro();
      if (AuthService.hasValidSession) {
        await SplashService.markSplashVideoSeen();
      }
    } else {
      final splashController = ref.read(splashControllerProvider);
      await splashController.stopPlayback();
      await SplashVideoModel.suppressIntro();
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

    if (target.route == AppRoutes.home) {
      AuthService.shouldRefreshHomeWallet = true;
      await AuthService.prefetchWalletBalanceForHome();
    }

    try {
      await Navigator.of(context).pushReplacementNamed(
        target.route,
        arguments: target.arguments,
      );
    } catch (error) {
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    } finally {
      ref.invalidate(splashControllerProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showIntroVideo) {
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
