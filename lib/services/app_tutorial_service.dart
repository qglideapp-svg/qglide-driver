import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';

/// Persists first-time in-app walkthrough state across auth and home segments.
class AppTutorialService {
  AppTutorialService._();

  static const _journeyActiveKey = 'tutorial_journey_active';
  static const _authSegmentDoneKey = 'tutorial_auth_segment_done';
  static const _homeSegmentDoneKey = 'tutorial_home_segment_done';
  static const _skippedKey = 'tutorial_skipped';
  static const _authCompletedRoutesKey = 'tutorial_auth_completed_routes';
  static const _routeStepIndexKey = 'tutorial_route_step_index';
  static const _replayRouteKey = 'tutorial_replay_route';

  static const authRouteOrder = [
    AppRoutes.signup,
    AppRoutes.verification,
    AppRoutes.documentUpload,
    AppRoutes.manageVehicle,
    AppRoutes.documentSubmissionSuccess,
    AppRoutes.login,
  ];

  static var _journeyActive = false;
  static var _authSegmentDone = false;
  static var _homeSegmentDone = false;
  static var _skipped = false;
  static Set<String> _authCompletedRoutes = {};
  static Map<String, int> _routeStepIndices = {};
  static String? _replayRoute;
  static var _prefsUnavailable = false;

  static bool get isJourneyActive => _journeyActive;
  static bool get isAuthSegmentDone => _authSegmentDone;
  static bool get isHomeSegmentDone => _homeSegmentDone;
  static bool get isSkipped => _skipped;
  static String? get replayRoute => _replayRoute;

  static Future<SharedPreferences?> _prefs() async {
    if (_prefsUnavailable) return null;
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      _prefsUnavailable = true;
      return null;
    }
  }

  static Future<void> loadFromDisk() async {
    final prefs = await _prefs();
    if (prefs == null) return;

    _journeyActive = prefs.getBool(_journeyActiveKey) ?? false;
    _authSegmentDone = prefs.getBool(_authSegmentDoneKey) ?? false;
    _homeSegmentDone = prefs.getBool(_homeSegmentDoneKey) ?? false;
    _skipped = prefs.getBool(_skippedKey) ?? false;
    _replayRoute = prefs.getString(_replayRouteKey);

    final completedRaw = prefs.getString(_authCompletedRoutesKey);
    if (completedRaw != null && completedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(completedRaw);
        if (decoded is List) {
          _authCompletedRoutes = decoded.map((e) => e.toString()).toSet();
        }
      } catch (_) {
        _authCompletedRoutes = {};
      }
    } else {
      _authCompletedRoutes = {};
    }

    final stepRaw = prefs.getString(_routeStepIndexKey);
    if (stepRaw != null && stepRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(stepRaw);
        if (decoded is Map) {
          _routeStepIndices = decoded.map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
          );
        }
      } catch (_) {
        _routeStepIndices = {};
      }
    } else {
      _routeStepIndices = {};
    }
  }

  static Future<void> activateJourney() async {
    _journeyActive = true;
    _authSegmentDone = false;
    _homeSegmentDone = false;
    _skipped = false;
    _authCompletedRoutes = {};
    _routeStepIndices = {};
    _replayRoute = null;

    final prefs = await _prefs();
    await prefs?.setBool(_journeyActiveKey, true);
    await prefs?.setBool(_authSegmentDoneKey, false);
    await prefs?.setBool(_homeSegmentDoneKey, false);
    await prefs?.setBool(_skippedKey, false);
    await prefs?.remove(_authCompletedRoutesKey);
    await prefs?.remove(_routeStepIndexKey);
    await prefs?.remove(_replayRouteKey);
  }

  static Future<void> markSkipped() async {
    _skipped = true;
    _journeyActive = false;
    _replayRoute = null;

    final prefs = await _prefs();
    await prefs?.setBool(_skippedKey, true);
    await prefs?.setBool(_journeyActiveKey, false);
    await prefs?.remove(_replayRouteKey);
  }

  static Future<void> completeRouteTutorial(String route) async {
    if (route == AppRoutes.home) {
      await completeHomeSegment();
      return;
    }

    if (authRouteOrder.contains(route)) {
      _authCompletedRoutes.add(route);
      _routeStepIndices.remove(route);

      final prefs = await _prefs();
      await prefs?.setString(
        _authCompletedRoutesKey,
        jsonEncode(_authCompletedRoutes.toList()),
      );
      await _persistStepIndices();

      if (route == AppRoutes.login) {
        await completeAuthSegment();
      }
    }
  }

  static Future<void> completeAuthSegment() async {
    _authSegmentDone = true;
    _routeStepIndices.removeWhere(
      (route, _) => authRouteOrder.contains(route),
    );

    final prefs = await _prefs();
    await prefs?.setBool(_authSegmentDoneKey, true);
    await _persistStepIndices();
  }

  static Future<void> completeHomeSegment() async {
    _homeSegmentDone = true;
    _journeyActive = false;
    _replayRoute = null;
    _routeStepIndices.remove(AppRoutes.home);

    final prefs = await _prefs();
    await prefs?.setBool(_homeSegmentDoneKey, true);
    await prefs?.setBool(_journeyActiveKey, false);
    await prefs?.remove(_replayRouteKey);
    await _persistStepIndices();
  }

  static bool shouldShowForRoute(String route) {
    if (_skipped && _replayRoute == null) return false;

    if (route == AppRoutes.home) {
      if (_homeSegmentDone && _replayRoute != AppRoutes.home) return false;
      if (!_authSegmentDone && _replayRoute != AppRoutes.home) return false;
      return _journeyActive || _replayRoute == AppRoutes.home;
    }

    if (!authRouteOrder.contains(route)) return false;
    if (_authSegmentDone && _replayRoute != route) return false;
    if (_authCompletedRoutes.contains(route) && _replayRoute != route) {
      return false;
    }

    if (_replayRoute != null) {
      return _replayRoute == route;
    }

    return _journeyActive;
  }

  static int stepIndexForRoute(String route) {
    return _routeStepIndices[route] ?? 0;
  }

  static Future<void> setStepIndexForRoute(String route, int index) async {
    _routeStepIndices[route] = index;
    await _persistStepIndices();
  }

  static Future<void> clearStepIndexForRoute(String route) async {
    _routeStepIndices.remove(route);
    await _persistStepIndices();
  }

  static Future<void> prepareReplay({
    required String route,
    bool resetHomeSegment = false,
    bool resetAuthSegment = false,
  }) async {
    _skipped = false;
    _replayRoute = route;

    if (resetHomeSegment) {
      _homeSegmentDone = false;
    }
    if (resetAuthSegment) {
      _authSegmentDone = false;
      _authCompletedRoutes = {};
    }

    if (route == AppRoutes.home) {
      _routeStepIndices.remove(AppRoutes.home);
    } else if (authRouteOrder.contains(route)) {
      _authCompletedRoutes.remove(route);
      _routeStepIndices.remove(route);
      if (resetAuthSegment) {
        _routeStepIndices.removeWhere(
          (key, _) => authRouteOrder.contains(key),
        );
      }
    }

    final prefs = await _prefs();
    await prefs?.setBool(_skippedKey, false);
    await prefs?.setString(_replayRouteKey, route);
    await prefs?.setBool(_homeSegmentDoneKey, _homeSegmentDone);
    await prefs?.setBool(_authSegmentDoneKey, _authSegmentDone);
    await prefs?.setString(
      _authCompletedRoutesKey,
      jsonEncode(_authCompletedRoutes.toList()),
    );
    await _persistStepIndices();

    if (route == AppRoutes.home) {
      _journeyActive = true;
      await prefs?.setBool(_journeyActiveKey, true);
    }
  }

  static Future<void> clearReplayRoute() async {
    _replayRoute = null;
    final prefs = await _prefs();
    await prefs?.remove(_replayRouteKey);
  }

  static Future<void> _persistStepIndices() async {
    final prefs = await _prefs();
    if (_routeStepIndices.isEmpty) {
      await prefs?.remove(_routeStepIndexKey);
      return;
    }
    await prefs?.setString(
      _routeStepIndexKey,
      jsonEncode(_routeStepIndices),
    );
  }
}
