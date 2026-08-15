import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/ad_placement_payload.dart';
import 'app_locale_service.dart';
import 'auth_service.dart';

class AdPlacementService {
  AdPlacementService._();

  static Future<Map<String, dynamic>> fetchPlacement(
    String placementKey, {
    bool authenticated = false,
    String? platform,
    int? appBuild,
  }) async {
    final languageCode = AppLocaleService.instance.languageCode;
    final queryParameters = <String, String>{
      'placement_key': placementKey,
      'lang': languageCode,
    };
    if (platform != null && platform.isNotEmpty) {
      queryParameters['platform'] = platform;
    }
    if (appBuild != null) {
      queryParameters['app_build'] = appBuild.toString();
    }

    final uri = Uri.parse(ApiConfig.adPlacementUrl).replace(
      queryParameters: queryParameters,
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept-Language': languageCode,
    };

    if (authenticated) {
      await AuthService.refreshSessionIfNeeded();
      final token = AuthService.accessToken;
      if (token == null || token.isEmpty) {
        return {'success': false};
      }
      headers['apikey'] = ApiConfig.supabaseAnonKey;
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      return {'success': false};
    }

    final body = response.body;
    if (body.isEmpty) {
      return {'success': false};
    }

    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return {'success': false};
  }
}

/// Keeps driver ad placements fresh via periodic polling and app-resume refresh.
class AdPlacementCache extends ChangeNotifier {
  AdPlacementCache._();

  static final AdPlacementCache instance = AdPlacementCache._();

  static const driverAccountBannerKey = 'driver_account_banner';
  static const driverTripCompleteKey = 'driver_trip_complete';
  static const driverWalletKey = 'driver_wallet';
  static const Duration bannerPollInterval = Duration(seconds: 4);
  static const Duration homeModalPollInterval = Duration(seconds: 4);

  final Map<String, AdPlacementPayload?> _cache = {};
  final Set<String> _loadedKeys = {};
  Timer? _timer;
  var _isPolling = false;
  var _started = false;

  AdPlacementPayload? get(String key) => _cache[key];

  bool hasLoaded(String key) => _loadedKeys.contains(key);

  void _putFromResponse(String key, Map<String, dynamic> response) {
    final payload = AdPlacementPayload.fromApiResponse(response);
    _cache[key] = (payload != null && payload.shouldShowForCurrentUser)
        ? payload
        : null;
    _loadedKeys.add(key);
  }

  bool _contentChanged(String key, AdPlacementPayload? before) {
    final after = _cache[key];
    if (before == null && after == null) return false;
    if (before == null || after == null) return true;
    return !after.contentEquals(before);
  }

  Future<void> refreshKey(
    String key, {
    bool authenticated = false,
  }) async {
    try {
      final response = await AdPlacementService.fetchPlacement(
        key,
        authenticated: authenticated,
      );
      final before = _cache[key];
      final wasLoaded = _loadedKeys.contains(key);
      _putFromResponse(key, response);
      if (!wasLoaded || _contentChanged(key, before)) {
        notifyListeners();
      }
    } catch (_) {
      final wasLoaded = _loadedKeys.contains(key);
      final hadContent = _cache[key] != null;
      _loadedKeys.add(key);
      _cache[key] = null;
      if (!wasLoaded || hadContent) {
        notifyListeners();
      }
    }
  }

  Future<void> pollDriverPlacements() async {
    if (_isPolling) return;
    _isPolling = true;
    try {
      await Future.wait([
        refreshKey(
          driverAccountBannerKey,
          authenticated: true,
        ),
        refreshKey(driverWalletKey),
      ]);
    } finally {
      _isPolling = false;
    }
  }

  /// Hot-reload compatibility — old timers may still reference this name.
  Future<void> pollDriverAccountBanner() => pollDriverPlacements();

  /// Begin 4s polling for driver ad placements.
  void start() {
    if (_started) return;
    _started = true;
    _restartPollingTimer();
    unawaited(pollDriverPlacements());
  }

  void _restartPollingTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(bannerPollInterval, (_) {
      unawaited(pollDriverPlacements());
    });
  }

  /// Immediate refresh — used on app resume.
  void refreshNow() {
    unawaited(pollDriverPlacements());
  }

  /// Clears cached copy and refetches after the user switches language.
  void refreshForLocaleChange() {
    _cache.clear();
    _loadedKeys.clear();
    notifyListeners();
    unawaited(pollDriverPlacements());
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }
}
