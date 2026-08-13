import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the intro splash video has already been shown.
class SplashService {
  SplashService._();

  static const _seenKey = 'splash_video_seen';

  static var _hasSeenSplashVideo = false;
  static var _prefsUnavailable = false;

  static bool get hasSeenSplashVideo => _hasSeenSplashVideo;

  /// True only on the very first app open before the intro video has finished once.
  static bool get shouldPlayIntroVideo => !_hasSeenSplashVideo;

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
