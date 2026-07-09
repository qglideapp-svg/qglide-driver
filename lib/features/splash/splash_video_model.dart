import 'package:video_player/video_player.dart';

import '../../config/app_constants.dart';

class SplashVideoModel {
  SplashVideoModel._();

  static Future<VideoPlayerController>? _future;

  static void preload() {
    _future ??= _create();
  }

  static Future<VideoPlayerController> load() {
    preload();
    return _future!;
  }

  static void reset() {
    _future = null;
  }

  static Future<VideoPlayerController> _create() async {
    final controller = VideoPlayerController.asset(
      AppConstants.splashVideoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await controller.initialize();
    await controller.setLooping(false);
    await controller.setVolume(1);
    return controller;
  }
}
