import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../config/app_constants.dart';

/// Owns the splash intro video player and ensures it cannot resume in background.
class SplashVideoModel {
  SplashVideoModel._();

  static VideoPlayerController? _controller;
  static Future<void>? _initializeFuture;
  static var _introSuppressed = false;
  static var _introWasStarted = false;

  static bool get isIntroSuppressed => _introSuppressed;

  static bool get introWasStarted => _introWasStarted;

  static bool get hasLiveController =>
      !_introSuppressed && _controller != null;

  /// Mutes and disposes the intro video; blocks future playback this session.
  static Future<void> suppressIntro() async {
    _introSuppressed = true;
    await stopAndDispose();
  }

  /// Stops intro playback only when the splash video was started this session.
  static Future<void> suppressIntroIfNeeded() async {
    if (_introSuppressed || !_introWasStarted) return;
    await suppressIntro();
  }

  static Future<VideoPlayerController> beginLoad() {
    if (_introSuppressed) {
      throw StateError('Splash intro suppressed');
    }

    _introWasStarted = true;
    _controller ??= VideoPlayerController.asset(
      AppConstants.splashVideoAsset,
      viewType: _splashVideoViewType(),
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
    await controller.setVolume(0);
  }

  static VideoViewType _splashVideoViewType() {
    if (!kIsWeb && Platform.isAndroid) {
      // TextureView can render audio-only black frames on some Android devices.
      return VideoViewType.platformView;
    }
    return VideoViewType.textureView;
  }
}
