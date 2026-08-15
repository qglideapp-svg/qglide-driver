import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../../config/app_constants.dart';
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

  bool get canRenderVideo =>
      hasVideoController &&
      isVideoReady &&
      !_isComplete &&
      SplashVideoModel.hasLiveController;

  bool get isComplete => _isComplete;

  Future<void> initialize() async {
    if (_disposed) return;

    if (!SplashService.shouldPlayIntroVideo) {
      unawaited(SplashVideoModel.suppressIntro());
      _markComplete();
      return;
    }

    if (SplashVideoModel.isIntroSuppressed) {
      _markComplete();
      return;
    }

    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(
      AppConstants.splashIntroMaxDuration + const Duration(seconds: 4),
      _markComplete,
    );

    try {
      final controller = await SplashVideoModel.beginLoad();
      if (_disposed) {
        await SplashVideoModel.stopAndDispose();
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

      notifyListeners();
      _scheduleFallbackTimer(controller.value.duration);
      if (SplashVideoModel.isIntroSuppressed) {
        _markComplete();
        return;
      }
      await controller.setVolume(1);
      await controller.play();
      notifyListeners();
    } catch (error) {
      _markComplete();
    }
  }

  void _scheduleFallbackTimer(Duration videoDuration) {
    _fallbackTimer?.cancel();
    final effectiveDuration = _effectiveIntroDuration(videoDuration);
    _fallbackTimer = Timer(
      effectiveDuration + const Duration(seconds: 2),
      _markComplete,
    );
  }

  Duration _effectiveIntroDuration(Duration videoDuration) {
    final maxDuration = AppConstants.splashIntroMaxDuration;
    if (videoDuration <= Duration.zero) return maxDuration;
    return videoDuration < maxDuration ? videoDuration : maxDuration;
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

    if (value.position >= _effectiveIntroDuration(value.duration)) {
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

  /// Detaches the player from the widget tree, then releases native resources.
  Future<void> teardownVideo() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    final controller = _videoController;
    _videoController = null;
    controller?.removeListener(_onVideoUpdate);
    if (!_disposed) {
      notifyListeners();
    }

    if (controller == null && !SplashVideoModel.hasLiveController) {
      return;
    }

    await SchedulerBinding.instance.endOfFrame;
    await SplashVideoModel.stopAndDispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    final controller = _videoController;
    _videoController = null;
    controller?.removeListener(_onVideoUpdate);
    super.dispose();
  }
}
