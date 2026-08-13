import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../services/auth_service.dart';
import '../../services/splash_service.dart';
import 'splash_video_model.dart';

class SplashController extends ChangeNotifier {
  VideoPlayerController? _videoController;
  Timer? _fallbackTimer;
  var _isComplete = false;
  var _disposed = false;

  VideoPlayerController? get videoController => _videoController;

  bool get hasVideoController =>
      !_disposed && _videoController != null;

  bool get isVideoReady =>
      !_disposed &&
      _videoController != null &&
      _videoController!.value.isInitialized;

  bool get isComplete => _isComplete;

  static bool get _shouldSkipIntroVideo =>
      SplashService.hasSeenSplashVideo || AuthService.hasValidSession;

  Future<void> initialize() async {
    if (_disposed) return;

    if (_shouldSkipIntroVideo) {
      _markComplete();
      return;
    }

    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 12), _markComplete);

    try {
      final controller = await SplashVideoModel.beginLoad();
      if (_disposed) {
        await controller.dispose();
        SplashVideoModel.reset();
        return;
      }

      _videoController = controller;
      controller.addListener(_onVideoUpdate);
      notifyListeners();

      await SplashVideoModel.load().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Splash video load timed out');
        },
      );
      if (_disposed) {
        return;
      }

      _scheduleFallbackTimer(controller.value.duration);
      await controller.play();
    } catch (error) {
      _markComplete();
    }
  }

  void _scheduleFallbackTimer(Duration videoDuration) {
    _fallbackTimer?.cancel();
    final timeout = videoDuration > Duration.zero
        ? videoDuration + const Duration(seconds: 2)
        : const Duration(seconds: 10);
    _fallbackTimer = Timer(timeout, _markComplete);
  }

  void _onVideoUpdate() {
    if (_disposed) return;

    final controller = _videoController;
    if (_isComplete || controller == null || !controller.value.isInitialized) {
      return;
    }

    final value = controller.value;
    if (value.hasError) {
      _markComplete();
      return;
    }

    if (_hasReachedEnd(value)) {
      _markComplete();
    }
  }

  bool _hasReachedEnd(VideoPlayerValue value) {
    if (value.isCompleted) return true;

    final duration = value.duration;
    if (duration <= Duration.zero) return false;

    final position = value.position;
    if (position <= Duration.zero) return false;

    final nearEnd = position >= duration - const Duration(milliseconds: 250);
    if (!nearEnd) return false;

    // Some platforms pause on the last frame without setting isCompleted.
    return !value.isPlaying || position >= duration;
  }

  void _markComplete() {
    if (_disposed || _isComplete) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _isComplete = true;
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    final controller = _videoController;
    if (controller != null) {
      controller.removeListener(_onVideoUpdate);
      _videoController = null;
      try {
        if (controller.value.isInitialized) {
          await controller.pause();
          await controller.setVolume(0);
        }
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
      SplashVideoModel.reset();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      controller.removeListener(_onVideoUpdate);
      unawaited(
        controller.dispose().catchError((_) {
          return null;
        }),
      );
      SplashVideoModel.reset();
    }
    super.dispose();
  }
}
