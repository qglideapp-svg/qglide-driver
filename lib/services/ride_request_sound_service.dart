import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../config/app_constants.dart';

class RideRequestSoundService {
  RideRequestSoundService._();

  static final AudioPlayer _player = AudioPlayer();
  static String? _lastRideId;
  static DateTime? _lastPlayedAt;
  static var _isLooping = false;
  static var _initialized = false;
  static Timer? _stopTimer;
  static Completer<void>? _playbackCompleter;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
    _initialized = true;
  }

  static Future<void> play(String rideId) async {
    await _startPlayback(rideId);
  }

  static Future<void> playForBackgroundAlert(String rideId) async {
    await _startPlayback(rideId);
    final completer = _playbackCompleter;
    if (completer == null) return;
    await completer.future;
  }

  static Future<void> _startPlayback(String rideId) async {
    final trimmedRideId = rideId.trim();
    if (trimmedRideId.isEmpty) return;

    final now = DateTime.now();
    final isSameRide = _lastRideId == trimmedRideId;
    if (isSameRide && _isLooping) return;

    final playedRecently = _lastPlayedAt != null &&
        now.difference(_lastPlayedAt!) < const Duration(seconds: 2);
    if (isSameRide && playedRecently) return;

    _lastRideId = trimmedRideId;
    _lastPlayedAt = now;

    try {
      await ensureInitialized();
      _stopTimer?.cancel();
      _completePlaybackWait();
      _playbackCompleter = Completer<void>();
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(AppConstants.rideRequestAlertSoundAsset));
      _isLooping = true;
      _stopTimer = Timer(AppConstants.rideRequestAcceptDuration, () {
        unawaited(stop());
      });
    } catch (_) {
      _isLooping = false;
      _stopTimer?.cancel();
      _stopTimer = null;
      _completePlaybackWait();
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  static Future<void> stop() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    if (!_isLooping) {
      _completePlaybackWait();
      return;
    }
    try {
      await _player.stop();
    } catch (_) {}
    _isLooping = false;
    _completePlaybackWait();
  }

  static void _completePlaybackWait() {
    final completer = _playbackCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _playbackCompleter = null;
  }
}
