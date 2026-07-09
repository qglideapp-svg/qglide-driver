import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../config/app_constants.dart';

class AddedStopArrivalSoundService {
  AddedStopArrivalSoundService._();

  static final AudioPlayer _player = AudioPlayer();
  static var _isPlaying = false;

  static Future<void> play() async {
    if (_isPlaying) return;

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(
        AssetSource(AppConstants.addedStopArrivalSoundAsset),
      );
      _isPlaying = true;
    } catch (_) {
      _isPlaying = false;
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  static Future<void> stop() async {
    if (!_isPlaying) return;

    try {
      await _player.stop();
    } catch (_) {}
    _isPlaying = false;
  }
}
