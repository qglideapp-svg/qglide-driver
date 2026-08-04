import 'dart:async';

import 'package:video_player/video_player.dart';

import '../../config/app_constants.dart';

class SplashVideoModel {
  SplashVideoModel._();

  static VideoPlayerController? _controller;
  static Future<void>? _initializeFuture;

  static Future<VideoPlayerController> beginLoad() {
    _controller ??= VideoPlayerController.asset(
      AppConstants.splashVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _initializeFuture ??= _initialize(_controller!);
    return Future.value(_controller!);
  }

  static Future<VideoPlayerController> load() async {
    final controller = await beginLoad();
    await _initializeFuture;
    return controller;
  }

  static void reset() {
    _controller = null;
    _initializeFuture = null;
  }

  static Future<void> _initialize(VideoPlayerController controller) async {
    await controller.initialize().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw TimeoutException('Splash video initialization timed out');
      },
    );
    await controller.setLooping(false);
    await controller.setVolume(1);
  }
}
