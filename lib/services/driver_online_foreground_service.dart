import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_strings.dart';
import 'auth_service.dart';

/// Top-level callback required by [FlutterForegroundTask.startService].
@pragma('vm:entry-point')
void driverOnlineForegroundStartCallback() {
  FlutterForegroundTask.setTaskHandler(DriverOnlineTaskHandler());
}

/// Keeps the driver available after the UI is backgrounded or swiped away by
/// posting location heartbeats from a sticky Android/iOS foreground task.
/// Uses foreground location access (FGS), not ACCESS_BACKGROUND_LOCATION.
class DriverOnlineTaskHandler extends TaskHandler {
  var _heartbeatInFlight = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await AuthService.loadStoredSession();
    } catch (_) {}
    await _postHeartbeat();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_postHeartbeat());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  Future<void> _postHeartbeat() async {
    if (_heartbeatInFlight) return;
    _heartbeatInFlight = true;
    try {
      if (!AuthService.isLoggedIn && !AuthService.hasStoredSession) {
        await AuthService.loadStoredSession();
      }
      if (!AuthService.isLoggedIn && !AuthService.hasStoredSession) return;

      await AuthService.refreshSessionIfNeeded();

      final position = await _resolveHeartbeatPosition();
      if (position == null) return;

      final heading = position.heading;
      await AuthService.updateDriverLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        heading: heading >= 0 && heading <= 360 && !heading.isNaN
            ? heading
            : null,
        isAvailable: true,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('DriverOnlineTaskHandler heartbeat failed: $e');
        debugPrint('$st');
      }
    } finally {
      _heartbeatInFlight = false;
    }
  }

  /// Prefer a recent last-known fix so FGS heartbeats do not compete with the
  /// UI position stream for a fresh high-accuracy GPS lock.
  Future<Position?> _resolveHeartbeatPosition() async {
    const maxCachedAge = Duration(seconds: 30);

    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        final age = DateTime.now().difference(cached.timestamp);
        if (age <= maxCachedAge) return cached;
      }

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (_) {
        return cached;
      }
    } catch (_) {
      return null;
    }
  }
}

class DriverOnlineForegroundService {
  DriverOnlineForegroundService._();

  static var _initialized = false;

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'driver_online_location',
        channelName: 'Driver online',
        channelDescription:
            'Keeps you available for ride requests while online',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(8000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  static Future<void> start() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    await init();

    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) return;

    final s = AppStrings.current();
    await FlutterForegroundTask.startService(
      serviceId: 256,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: s.backgroundLocationNotificationTitle,
      notificationText: s.backgroundLocationNotificationBody,
      callback: driverOnlineForegroundStartCallback,
    );
  }

  static Future<void> stop() async {
    if (kIsWeb) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
