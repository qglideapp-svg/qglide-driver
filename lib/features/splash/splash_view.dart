import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app_bootstrap.dart';
import '../../core/providers/app_providers.dart';
import '../../config/app_constants.dart';
import '../../routes/app_routes.dart';
import '../../services/app_update_service.dart';
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
  static const _returningUserMinLogoDuration = Duration.zero;
  static const _returningUserMaxWait = Duration(seconds: 2);
  static const _returningUserStartupGate = Duration(milliseconds: 400);

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
    AppUpdateService.placementNotifier.addListener(_onForceUpdateStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showIntroVideo) {
        _beginIntroVideo();
      }
      unawaited(_prepareSplashNavigation());
    });
  }

  void _beginIntroVideo() {
    _splashSubscription ??= ref.listenManual(
      splashControllerProvider,
      (previous, next) {
        if (next.isComplete) {
          _maybeScheduleNavigation();
        }
      },
    );
    unawaited(ref.read(splashControllerProvider).initialize());
  }

  Future<void> _prepareSplashNavigation() async {
    if (!_showIntroVideo) {
      await _waitForReturningUserStartupGate();
    } else {
      await AppUpdateService.waitUntilReady();
    }
    if (!mounted) return;

    if (AppUpdateService.isBlocking) return;

    if (!_showIntroVideo) {
      unawaited(_startReturningUserSplash());
      _startupFallbackTimer ??= Timer(_returningUserMaxWait, () {
        if (!mounted || _hasNavigated) return;
        _maybeScheduleNavigation();
      });
      return;
    }

    _startupFallbackTimer ??= Timer(
      AppConstants.splashIntroMaxDuration + const Duration(seconds: 5),
      () {
        if (!mounted || _hasNavigated) return;
        _maybeScheduleNavigation();
      },
    );

    _maybeScheduleNavigation();
  }

  void _onForceUpdateStateChanged() {
    if (!mounted || _hasNavigated || AppUpdateService.isBlocking) return;
    _maybeScheduleNavigation();
  }

  void _maybeScheduleNavigation() {
    if (_hasNavigated ||
        !mounted ||
        AppUpdateService.isBlocking ||
        StartupNavigationTracker.hasLeftSplash) {
      return;
    }

    if (_showIntroVideo) {
      final splash = ref.read(splashControllerProvider);
      if (!splash.isComplete) return;
    }

    _scheduleNavigation();
  }

  Future<void> _waitForReturningUserStartupGate() async {
    if (AppUpdateService.isBlocking) {
      await AppUpdateService.waitUntilReady();
      return;
    }

    try {
      await AppUpdateService.waitUntilReady().timeout(_returningUserStartupGate);
    } on TimeoutException {
      // Proceed to home; force-update overlay can appear once the poll finishes.
    }
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
    _maybeScheduleNavigation();
  }

  @override
  void dispose() {
    AppUpdateService.placementNotifier.removeListener(_onForceUpdateStateChanged);
    _startupFallbackTimer?.cancel();
    _splashSubscription?.close();
    unawaited(SplashVideoModel.suppressIntroIfNeeded());
    super.dispose();
  }

  Future<DriverNavigationTarget> _resolveNavigationTarget() async {
    if (!_showIntroVideo && AuthService.hasValidSession) {
      final fastTarget =
          await DriverAuthNavigation.resolveFastReturningSplashTarget();
      if (fastTarget != null) {
        return fastTarget;
      }
    }

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
    if (AppUpdateService.isBlocking) return;
    _hasNavigated = true;
    _startupFallbackTimer?.cancel();
    StartupNavigationTracker.markNavigated();
    unawaited(_navigateAfterSplash());
  }

  Future<void> _navigateAfterSplash() async {
    if (_showIntroVideo) {
      await ref.read(splashControllerProvider).teardownVideo();
    } else {
      await SplashVideoModel.suppressIntro();
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

    if (AppUpdateService.isBlocking) {
      _hasNavigated = false;
      return;
    }

    if (target.route == AppRoutes.home) {
      AuthService.shouldRefreshHomeWallet = true;
      unawaited(AuthService.prefetchWalletBalanceForHome());
    }

    try {
      if (!mounted) return;
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
        _maybeScheduleNavigation();
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (controller.canRenderVideo)
            _SplashVideoPlayer(
              key: ValueKey(controller.videoController),
              controller: controller.videoController!,
            ),
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

class _SplashVideoPlayer extends StatefulWidget {
  const _SplashVideoPlayer({
    super.key,
    required this.controller,
  });

  final VideoPlayerController controller;

  @override
  State<_SplashVideoPlayer> createState() => _SplashVideoPlayerState();
}

class _SplashVideoPlayerState extends State<_SplashVideoPlayer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoTick);
  }

  @override
  void didUpdateWidget(covariant _SplashVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onVideoTick);
      widget.controller.addListener(_onVideoTick);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoTick);
    super.dispose();
  }

  void _onVideoTick() {
    if (!mounted ||
        SplashVideoModel.isIntroSuppressed ||
        !SplashVideoModel.hasLiveController) {
      return;
    }
    setState(() {});
  }

  bool _canBuildPlayer() {
    if (SplashVideoModel.isIntroSuppressed || !SplashVideoModel.hasLiveController) {
      return false;
    }
    try {
      return widget.controller.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canBuildPlayer()) {
      return const SizedBox.shrink();
    }

    final value = widget.controller.value;
    final videoWidth = value.size.width;
    final videoHeight = value.size.height;
    if (videoWidth > 0 && videoHeight > 0) {
      return SizedBox.expand(
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: videoWidth,
              height: videoHeight,
              child: VideoPlayer(widget.controller),
            ),
          ),
        ),
      );
    }

    final aspectRatio = value.aspectRatio > 0 ? value.aspectRatio : 9 / 16;
    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: VideoPlayer(widget.controller),
          ),
        ),
      ),
    );
  }
}
