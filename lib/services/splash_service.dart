import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Tracks whether the intro splash video has already been shown.
class SplashService {
  SplashService._();

  static const _seenKey = 'splash_video_seen';

  static var _hasSeenSplashVideo = false;
  static var _prefsUnavailable = false;

  static bool get hasSeenSplashVideo => _hasSeenSplashVideo;

  /// Intro plays until the driver finishes the onboarding carousel.
  static bool get shouldPlayIntroVideo => !AuthService.hasCompletedOnboarding;

  static Future<void> loadFromDisk() async {
    if (_prefsUnavailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenSplashVideo = prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      _prefsUnavailable = true;
    }
  }

  static Future<void> markSplashVideoSeen() async {
    if (_hasSeenSplashVideo) return;
    _hasSeenSplashVideo = true;
    if (_prefsUnavailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {
      _prefsUnavailable = true;
    }
  }
}
