import 'dart:async';

import 'package:video_player/video_player.dart';

import '../../config/app_constants.dart';

/// Owns the splash intro video player and ensures it cannot resume in background.
class SplashVideoModel {
  SplashVideoModel._();

  static VideoPlayerController? _controller;
  static Future<void>? _initializeFuture;
  static var _introSuppressed = false;

  static bool get isIntroSuppressed => _introSuppressed;

  /// Mutes and disposes the intro video; blocks future playback this session.
  static Future<void> suppressIntro() async {
    _introSuppressed = true;
    await stopAndDispose();
  }

  static Future<VideoPlayerController> beginLoad() {
    if (_introSuppressed) {
      throw StateError('Splash intro suppressed');
    }

    _controller ??= VideoPlayerController.asset(
      AppConstants.splashVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _initializeFuture ??= _initialize(_controller!);
    return Future.value(_controller!);
  }

  static Future<VideoPlayerController> load() async {
    if (_introSuppressed) {
      throw StateError('Splash intro suppressed');
    }

    final controller = await beginLoad();
    await _initializeFuture;
    if (_introSuppressed) {
      throw StateError('Splash intro suppressed');
    }
    return controller;
  }

  /// Stops playback and releases the splash video player.
  static Future<void> stopAndDispose() async {
    final controller = _controller;
    final initFuture = _initializeFuture;
    reset();
    if (controller == null) return;

    _muteAndPause(controller);

    if (initFuture != null) {
      try {
        await initFuture;
      } catch (_) {}
      _muteAndPause(controller);
    }

    try {
      await controller.dispose();
    } catch (_) {}
  }

  static void reset() {
    _controller = null;
    _initializeFuture = null;
  }

  static void _muteAndPause(VideoPlayerController controller) {
    try {
      if (controller.value.isInitialized) {
        controller.pause();
        controller.setVolume(0);
      }
    } catch (_) {}
  }

  static Future<void> _initialize(VideoPlayerController controller) async {
    await controller.initialize().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw TimeoutException('Splash video initialization timed out');
      },
    );

    if (_introSuppressed) {
      _muteAndPause(controller);
      throw StateError('Splash intro suppressed');
    }

    await controller.setLooping(false);
    await controller.setVolume(1);
  }
}
