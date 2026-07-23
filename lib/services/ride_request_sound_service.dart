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
  static var _playbackSuppressed = false;
  static var _playGeneration = 0;
  static Timer? _stopTimer;

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

  /// Prevents new ride-request sounds while the driver has accepted or is on a ride.
  static Future<void> suppressPlayback() async {
    _playbackSuppressed = true;
    await stop();
  }

  static void allowPlayback() {
    _playbackSuppressed = false;
  }

  static Future<void> play(String rideId) async {
    await _startPlayback(rideId);
  }

  static Future<void> _startPlayback(String rideId) async {
    if (_playbackSuppressed) return;

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
    final generation = ++_playGeneration;

    try {
      await ensureInitialized();
      if (_playbackSuppressed || generation != _playGeneration) return;

      _stopTimer?.cancel();
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(AppConstants.rideRequestAlertSoundAsset));

      if (_playbackSuppressed || generation != _playGeneration) {
        await _player.stop();
        return;
      }

      _isLooping = true;
      _stopTimer = Timer(AppConstants.rideRequestAcceptDuration, () {
        unawaited(stop());
      });
    } catch (_) {
      if (generation != _playGeneration) return;
      _isLooping = false;
      _stopTimer?.cancel();
      _stopTimer = null;
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  static Future<void> stop() async {
    _playGeneration++;
    _stopTimer?.cancel();
    _stopTimer = null;
    try {
      await _player.stop();
    } catch (_) {}
    _isLooping = false;
  }
}
