import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_constants.dart';
import '../config/app_strings.dart';
import '../app_navigator_key.dart';
import '../features/ride/call/in_app_call_args.dart';
import '../features/ride/call/in_app_call_view.dart';
import '../features/ride/call/models/zego_call_session.dart';
import '../routes/app_routes.dart';
import 'auth_service.dart';
import 'ride_request_sound_service.dart';

const _driverUserType = 'driver';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}

  if (!PushNotificationService.isNotificationForDriver(message.data)) {
    return;
  }

  final data = Map<String, dynamic>.from(message.data);
  if (PushNotificationService.isIncomingCall(data)) {
    return;
  }

  if (PushNotificationService.isRideRequestNotification(data)) {
    await PushNotificationService.showRideRequestNotification(data: data);
    return;
  }

  if (Platform.isIOS || message.notification == null) {
    await PushNotificationService.showLocalNotificationForMessage(message);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static var _initialized = false;
  static var _isAppReady = false;
  static Map<String, dynamic>? _pendingNotificationData;
  static String? _cachedDeviceId;
  static String? _cachedDeviceType;
  static String? _lastOpenedIncomingCallId;
  static DateTime? _lastOpenedIncomingAt;

  /// Called when the driver opens a ride-request notification. Registered by
  /// [HomeController] so nearby rides can be fetched and the accept panel shown.
  static Future<void> Function(Map<String, dynamic> data)?
      onRideRequestNotificationOpened;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    await _requestPermissions();
    await RideRequestSoundService.ensureInitialized();
    await _initializeLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleForegroundMessage(message));
    });

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await _ensureIosApnsToken();
    }

    _messaging.onTokenRefresh.listen((_) {
      unawaited(registerTokenIfLoggedIn());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAppReady();
    });

    _initialized = true;
    await registerTokenIfLoggedIn();
  }

  static Future<void> registerTokenIfLoggedIn() async {
    if (!_initialized || kIsWeb || !AuthService.isLoggedIn) return;

    try {
      if (Platform.isIOS) {
        final hasApnsToken = await _ensureIosApnsToken();
        if (!hasApnsToken) return;
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'PushNotificationService: FCM token is null or empty',
          );
        }
        return;
      }

      final deviceInfo = await _getDeviceInfo();
      final result = await AuthService.registerFcmToken(
        deviceToken: token,
        deviceType: deviceInfo['device_type']!,
        deviceId: deviceInfo['device_id'],
      );
      if (kDebugMode && result['success'] != true) {
        debugPrint(
          'PushNotificationService: register-fcm-token failed: '
          '${result['error']}',
        );
      }
    } on FirebaseException catch (e) {
      if (e.plugin == 'firebase_messaging' &&
          e.code == 'apns-token-not-set') {
        return;
      }
      if (kDebugMode) {
        debugPrint(
          'PushNotificationService: FCM token error: ${e.code} ${e.message}',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('PushNotificationService: FCM token error: $e');
        debugPrint('$stackTrace');
      }
    }
  }

  static bool isNotificationForDriver(Map<String, dynamic> data) {
    final target = data['target_user_type']?.toString().trim().toLowerCase();
    if (target == null || target.isEmpty) return true;
    if (target == 'all') return true;
    return target == _driverUserType;
  }

  static bool isIncomingCall(Map<String, dynamic> data) {
    final type = data['type'] ??
        data['notification_type'] ??
        data['call_type'];
    return type?.toString().trim().toLowerCase() == 'incoming_call';
  }

  static bool isRideRequestNotification(Map<String, dynamic> data) {
    return data['type']?.toString().trim().toLowerCase() == 'new_ride_request';
  }

  static NotificationDetails _rideRequestNotificationDetails() {
    final androidDetails = AndroidNotificationDetails(
      AppConstants.rideRequestNotificationChannelId,
      'Ride Requests',
      channelDescription: 'Alerts when a new ride request is available',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.alarm,
      sound: RawResourceAndroidNotificationSound(
        AppConstants.rideRequestNotificationSound,
      ),
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: '${AppConstants.rideRequestNotificationSound}.wav',
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  static Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.isAndroid) {
      final plugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.requestNotificationsPermission();
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        unawaited(RideRequestSoundService.stop());
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            _handleNotificationData(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'driver_notifications',
        'Driver Notifications',
        description: 'Ride, call, and earnings notifications for drivers',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      const rideRequestChannel = AndroidNotificationChannel(
        AppConstants.rideRequestNotificationChannelId,
        'Ride Requests',
        description: 'Alerts when a new ride request is available',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound(
          AppConstants.rideRequestNotificationSound,
        ),
        playSound: true,
        enableVibration: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(rideRequestChannel);
    }
  }

  static void _markAppReady() {
    if (_isAppReady) return;
    _isAppReady = true;
    _setupNotificationOpenHandlers();

    final pending = _pendingNotificationData;
    if (pending == null) return;
    _pendingNotificationData = null;
    _processNotificationData(pending);
  }

  static Future<void> showRideRequestNotification({
    required Map<String, dynamic> data,
  }) async {
    final rideId = data['ride_id']?.toString() ?? '';
    final pickupAddress = data['pickup_address']?.toString() ?? '';
    final dropoffAddress = data['dropoff_address']?.toString() ?? '';
    final riderName = data['rider_name']?.toString();
    final s = AppStrings.current();
    final title = s.newRideRequestTitle(riderName: riderName);
    final body = s.newRideRequestBody(
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
    );

    final payload = Map<String, dynamic>.from(data);
    payload['type'] = 'new_ride_request';
    payload['target_user_type'] = _driverUserType;
    if (rideId.isNotEmpty) {
      payload['ride_id'] = rideId;
    }

    await _localNotifications.show(
      rideId.isEmpty ? data.hashCode : rideId.hashCode,
      title,
      body,
      _rideRequestNotificationDetails(),
      payload: jsonEncode(payload),
    );
  }

  static Future<void> showLocalNotificationForMessage(
    RemoteMessage message,
  ) async {
    final s = AppStrings.current();
    final rawTitle = message.notification?.title ??
        message.data['title']?.toString() ??
        s.qglide;
    final rawBody = message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';

    final title = s.localizeKnownNotificationText(
      rawTitle,
      isTitle: true,
    );
    final body = rawBody.isEmpty
        ? ''
        : s.localizeKnownNotificationText(rawBody);

    if (body.isEmpty && title == s.qglide) return;

    final details = isRideRequestNotification(message.data)
        ? _rideRequestNotificationDetails()
        : const NotificationDetails(
            android: AndroidNotificationDetails(
              'driver_notifications',
              'Driver Notifications',
              channelDescription:
                  'Ride, call, and earnings notifications for drivers',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  static void _setupNotificationOpenHandlers() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (!isNotificationForDriver(message.data)) return;
      _handleNotificationData(Map<String, dynamic>.from(message.data));
    });

    unawaited(
      _messaging.getInitialMessage().then((message) {
        if (message == null) return;
        if (!isNotificationForDriver(message.data)) return;
        Future.delayed(const Duration(milliseconds: 100), () {
          _handleNotificationData(Map<String, dynamic>.from(message.data));
        });
      }),
    );
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!isNotificationForDriver(message.data)) return;

    final data = Map<String, dynamic>.from(message.data);
    if (isIncomingCall(data)) {
      _handleIncomingCall(data);
      return;
    }

    if (isRideRequestNotification(data)) {
      final rideId = data['ride_id']?.toString() ?? '';
      if (rideId.isNotEmpty) {
        unawaited(RideRequestSoundService.play(rideId));
      }
      if (Platform.isAndroid) {
        await showRideRequestNotification(data: data);
      }
      return;
    }

    await showLocalNotificationForMessage(message);
  }

  static void _handleNotificationData(Map<String, dynamic> data) {
    if (!_isAppReady) {
      _pendingNotificationData = data;
      return;
    }
    _processNotificationData(data);
  }

  static void _processNotificationData(Map<String, dynamic> data) {
    if (!isNotificationForDriver(data)) return;

    if (isIncomingCall(data)) {
      _handleIncomingCall(data);
      return;
    }

    if (isRideRequestNotification(data)) {
      _openRideRequestFromNotification(data);
      return;
    }

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamed(AppRoutes.notifications);
  }

  static void _openRideRequestFromNotification(Map<String, dynamic> data) {
    unawaited(RideRequestSoundService.stop());
    unawaited(_invokeRideRequestOpenedHandler(data));

    void navigate() {
      final nav = appNavigatorKey.currentState;
      if (nav == null) return;

      var onHome = false;
      nav.popUntil((route) {
        onHome = route.settings.name == AppRoutes.home;
        return onHome || route.isFirst;
      });
      if (!onHome) {
        nav.pushNamed(AppRoutes.home);
      }
    }

    SchedulerBinding.instance.addPostFrameCallback((_) => navigate());
  }

  static Future<void> _invokeRideRequestOpenedHandler(
    Map<String, dynamic> data,
  ) async {
    for (var attempt = 0; attempt < 15; attempt++) {
      final handler = onRideRequestNotificationOpened;
      if (handler != null) {
        await handler(data);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  static void _handleIncomingCall(Map<String, dynamic> data) {
    final payload = IncomingCallPayload.tryParse(data);
    if (payload == null) return;

    final now = DateTime.now();
    if (_lastOpenedIncomingCallId == payload.callId &&
        _lastOpenedIncomingAt != null &&
        now.difference(_lastOpenedIncomingAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastOpenedIncomingCallId = payload.callId;
    _lastOpenedIncomingAt = now;

    final callerName = data['caller_name']?.toString().trim();
    final counterpartName =
        callerName != null && callerName.isNotEmpty ? callerName : 'Rider';

    void openCall() {
      final nav = appNavigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => InAppCallView(
            args: InAppCallArgs(
              rideId: payload.rideId,
              counterpartName: counterpartName,
              incomingPayload: payload,
            ),
          ),
        ),
      );
    }

    SchedulerBinding.instance.addPostFrameCallback((_) => openCall());
  }

  static Future<bool> _ensureIosApnsToken() async {
    if (!Platform.isIOS) return true;
    for (var attempt = 0; attempt < 30; attempt++) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  static Future<Map<String, String>> _getDeviceInfo() async {
    if (_cachedDeviceId != null && _cachedDeviceType != null) {
      return {
        'device_type': _cachedDeviceType!,
        'device_id': _cachedDeviceId!,
      };
    }

    var deviceType = 'unknown';
    var deviceId = 'unknown-device';

    if (Platform.isAndroid) {
      deviceType = 'android';
      final info = await _deviceInfo.androidInfo;
      deviceId = info.id.isNotEmpty
          ? info.id
          : 'android-${DateTime.now().millisecondsSinceEpoch}';
    } else if (Platform.isIOS) {
      deviceType = 'ios';
      final info = await _deviceInfo.iosInfo;
      deviceId = info.identifierForVendor ??
          'ios-${DateTime.now().millisecondsSinceEpoch}';
    }

    _cachedDeviceType = deviceType;
    _cachedDeviceId = deviceId;
    return {'device_type': deviceType, 'device_id': deviceId};
  }
}
