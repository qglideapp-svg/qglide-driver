import 'dart:convert';
import 'dart:io' show Platform;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/app_constants.dart';
import 'app_locale_service.dart';

enum LocationSettingsAction { appSettings, locationServices }

class DriverLocation {
  const DriverLocation({
    required this.latitude,
    required this.longitude,
    this.placeName,
  });

  final double latitude;
  final double longitude;
  final String? placeName;

  String? get displayName {
    final name = placeName?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }
}

class LocationAccessResult {
  const LocationAccessResult.success(this.location)
      : error = null,
        settingsAction = null;

  const LocationAccessResult.error(
    this.error, [
    this.settingsAction,
  ]) : location = null;

  final DriverLocation? location;
  final String? error;
  final LocationSettingsAction? settingsAction;

  const LocationAccessResult.ok()
      : location = null,
        error = null,
        settingsAction = null;

  bool get isOk => error == null;
  bool get isSuccess => location != null;
}

class LocationTrackerService {
  LocationTrackerService._();

  static Future<LocationAccessResult> getCurrentLocation({
    bool requestPermissionIfNeeded = true,
    bool resolvePlaceName = false,
  }) async {
    final access = await _ensureLocationAccess(
      requestIfNeeded: requestPermissionIfNeeded,
    );
    if (access != null) {
      return access;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      String? placeName;
      if (resolvePlaceName) {
        placeName = await _resolvePlaceName(
          position.latitude,
          position.longitude,
        );
      }

      return LocationAccessResult.success(
        DriverLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          placeName: placeName,
        ),
      );
    } catch (_) {
      return const LocationAccessResult.error(
        'Could not get your location. Make sure GPS is enabled and try again.',
        LocationSettingsAction.locationServices,
      );
    }
  }

  static Future<String?> _resolvePlaceName(
    double latitude,
    double longitude,
  ) async {
    final googleName = await _resolvePlaceNameWithGoogle(latitude, longitude);
    if (googleName != null) return googleName;

    return _resolvePlaceNameWithPlatform(latitude, longitude);
  }

  static Future<String?> _resolvePlaceNameWithGoogle(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '$latitude,$longitude',
          'key': AppConstants.googleMapsApiKey,
          'language': AppLocaleService.instance.languageCode,
        },
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      return _formatGoogleAddress(results.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _resolvePlaceNameWithPlatform(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;
      return _formatPlacemark(placemarks.first);
    } catch (_) {
      return null;
    }
  }

  static String? _formatGoogleAddress(Map<String, dynamic> result) {
    final components = (result['address_components'] as List<dynamic>?) ?? [];

    String? component(String type) {
      for (final raw in components) {
        final map = raw as Map<String, dynamic>;
        final types = (map['types'] as List<dynamic>?) ?? const [];
        if (types.contains(type)) {
          return map['long_name'] as String?;
        }
      }
      return null;
    }

    final route = component('route');
    final area = component('sublocality') ??
        component('neighborhood') ??
        component('sublocality_level_1') ??
        component('establishment') ??
        component('administrative_area_level_2');
    final city = component('locality') ?? component('administrative_area_level_1');

    final parts = <String>[];
    void add(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty || parts.contains(trimmed)) {
        return;
      }
      parts.add(trimmed);
    }

    add(route);
    add(area);
    add(city);

    if (parts.isNotEmpty) {
      return parts.take(2).join(', ');
    }

    final formatted = result['formatted_address'] as String?;
    if (formatted == null || formatted.trim().isEmpty) return null;

    final segments = formatted
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty && !_looksLikePlusCode(segment))
        .toList();

    if (segments.isEmpty) return null;
    return segments.take(2).join(', ');
  }

  static String _formatPlacemark(Placemark place) {
    final parts = <String>[];

    void add(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) return;
      if (parts.contains(trimmed)) return;
      parts.add(trimmed);
    }

    add(place.street);
    add(place.subLocality);
    add(place.locality);
    add(place.administrativeArea);

    if (parts.isEmpty) {
      add(place.name);
      add(place.country);
    }

    if (parts.isEmpty) return 'Unknown location';
    return parts.take(2).join(', ');
  }

  static bool _looksLikePlusCode(String value) {
    return RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,}$').hasMatch(value);
  }

  static Future<LocationAccessResult?> _ensureLocationAccess({
    required bool requestIfNeeded,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationAccessResult.error(
        'Turn on Location Services to show your position.',
        LocationSettingsAction.locationServices,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return const LocationAccessResult.error(
        'Location access is blocked. Enable it in Settings for QGlide Driver.',
        LocationSettingsAction.appSettings,
      );
    }

    if (requestIfNeeded && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationAccessResult.error(
        'Location access is blocked. Enable it in Settings for QGlide Driver.',
        LocationSettingsAction.appSettings,
      );
    }

    if (permission == LocationPermission.denied) {
      return const LocationAccessResult.error(
        'Allow location access when prompted to show your position.',
      );
    }

    return null;
  }

  static var _backgroundAccessPromptAttempted = false;

  /// Requests Always / background location after When-In-Use is granted.
  ///
  /// Prompts at most once per app session so system permission dialogs do not
  /// thrash app lifecycle (pause → resume → reload loops). Going online must
  /// not fail if Always is denied — foreground / FGS tracking still works.
  static Future<bool> ensureBackgroundLocationAccess() async {
    final access = await _ensureLocationAccess(requestIfNeeded: true);
    if (access != null) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) return true;

    if (_backgroundAccessPromptAttempted) {
      return permission == LocationPermission.always;
    }
    _backgroundAccessPromptAttempted = true;

    if (permission == LocationPermission.whileInUse) {
      // Android 10+ / iOS: second prompt upgrades to Always when declared.
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always;
  }

  /// Continuous GPS updates for live map movement while the UI is alive.
  ///
  /// Background/killed heartbeats are handled by
  /// [DriverOnlineForegroundService] (sticky FGS), not this stream.
  static Stream<Position> watchPosition({required bool enRoute}) {
    if (Platform.isAndroid) {
      return Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: enRoute ? 5 : 10,
          intervalDuration: Duration(milliseconds: enRoute ? 1000 : 5000),
        ),
      );
    }

    if (Platform.isIOS) {
      return Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: enRoute ? 5 : 10,
          activityType: enRoute
              ? ActivityType.automotiveNavigation
              : ActivityType.other,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        ),
      );
    }

    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: enRoute ? 5 : 10,
      ),
    );
  }
}
