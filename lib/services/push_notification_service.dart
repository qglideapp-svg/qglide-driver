import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../config/app_strings.dart';
import '../app_navigator_key.dart';
import '../features/home/models/nearby_ride_offer.dart';
import '../features/ride/call/in_app_call_args.dart';
import '../features/ride/call/in_app_call_view.dart';
import '../features/ride/call/models/zego_call_session.dart';
import '../routes/app_routes.dart';
import 'active_ride_storage.dart';
import 'app_locale_service.dart';
import 'auth_service.dart';
import 'location_tracker_service.dart';
import 'ride_request_sound_service.dart';

const _driverUserType = 'driver';
const _pendingRideNotificationActionKey = 'pending_ride_notification_action';
const _pendingRideNotificationOpenKey = 'pending_ride_notification_open';
const _nativeOpenHomeForRideLaunchKey = 'should_open_home_for_ride_launch';
const _nativeRideAlertShownPrefix = 'native_ride_alert_shown_';
const _rideNotificationsChannel =
    MethodChannel('com.alphatecks.driver/ride_notifications');

/// Handles ride-request notification actions when the app is backgrounded.
@pragma('vm:entry-point')
void rideRequestNotificationBackgroundResponse(NotificationResponse response) {
  unawaited(PushNotificationService.handleBackgroundNotificationResponse(response));
}

/// Runs in a separate isolate when the app is backgrounded/terminated.
/// Local notifications must be re-initialized here — static state from the
/// main isolate is not shared.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}

  try {
    await AppLocaleService.instance.load();
  } catch (_) {}

  try {
    await PushNotificationService.ensureLocalNotificationsReady();
  } catch (e, st) {
    PushNotificationService.logNotificationIssue(
      'Background local-notification init failed',
      e,
      st,
    );
  }

  if (!PushNotificationService.isNotificationForDriver(message.data)) {
    return;
  }

  if (PushNotificationService.isIncomingCall(message.data)) {
    return;
  }

  final ridePayload = PushNotificationService.resolveRideRequestPayload(message);
  if (ridePayload != null) {
    final rideId = ridePayload['ride_id']?.toString() ?? '';
    if (Platform.isIOS &&
        await PushNotificationService.wasNativeRideRequestRecentlyShown(rideId)) {
      return;
    }
    try {
      await PushNotificationService.showRideRequestNotification(data: ridePayload);
    } catch (e, st) {
      PushNotificationService.logNotificationIssue(
        'showRideRequestNotification failed in background handler',
        e,
        st,
      );
    }
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
  static var _permissionsReady = false;
  static var _localNotificationsReady = false;
  static var _isAppReady = false;
  static var _initialMessageConsumed = false;
  static var _launchedFromRideRequestNotification = false;
  static var _pendingRideHandlerInvoked = false;
  static Map<String, dynamic>? _pendingNotificationData;
  static String? _cachedDeviceId;
  static String? _cachedDeviceType;
  static String? _lastOpenedIncomingCallId;
  static DateTime? _lastOpenedIncomingAt;

  /// Called when the driver opens a ride-request notification. Registered by
  /// [HomeController] so nearby rides can be fetched and the accept panel shown.
  static Future<void> Function(Map<String, dynamic> data)?
      onRideRequestNotificationOpened;

  /// Called when the driver taps Accept or Ignore on a ride-request notification.
  static Future<void> Function(String action, Map<String, dynamic> data)?
      onRideRequestNotificationAction;

  /// Called when the rider cancels a ride that is still shown to the driver.
  static Future<void> Function(Map<String, dynamic> data)?
      onRideCancelledNotification;

  static var _pendingRideActionInvoked = false;
  static var _isConsumingPendingRideAction = false;
  static var _launchPayloadCaptured = false;
  static Timer? _iosTokenRetryTimer;
  static var _iosTokenRetryAttempts = 0;
  static String? _lastKnownRideRequestId;

  /// Last ride-request id seen from push or polling (used to cancel native alerts).
  static String? get lastKnownRideRequestId => _lastKnownRideRequestId;

  /// True when the process was started by tapping a ride-request notification.
  static bool get shouldOpenHomeForRideLaunch =>
      _launchedFromRideRequestNotification;

  static void _rememberRideRequestId(Map<String, dynamic> data) {
    final rideId = data['ride_id']?.toString();
    if (rideId != null && rideId.isNotEmpty) {
      _lastKnownRideRequestId = rideId;
    }
  }

  /// Stops in-app loop audio and cancels the native ride-request notification.
  static Future<void> stopAllRideRequestAlerts({String? rideId}) async {
    await RideRequestSoundService.stop();
    final resolvedRideId = rideId ?? _lastKnownRideRequestId;
    if (resolvedRideId != null && resolvedRideId.isNotEmpty) {
      await cancelRideRequestNotification(resolvedRideId);
    }
  }

  /// Re-reads stashed native notification state when the app resumes from background.
  static Future<void> processPendingRideNotificationHandlersOnResume() async {
    if (kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      if (prefs.getBool(_nativeOpenHomeForRideLaunchKey) == true) {
        _launchedFromRideRequestNotification = true;
        await prefs.remove(_nativeOpenHomeForRideLaunchKey);
      }

      final pendingOpen = prefs.getString(_pendingRideNotificationOpenKey);
      if (pendingOpen != null && pendingOpen.isNotEmpty) {
        try {
          final decoded = jsonDecode(pendingOpen);
          if (decoded is Map) {
            final data = Map<String, dynamic>.from(decoded);
            _rememberRideRequestId(data);
            _stashLaunchNotificationData(data);
          }
        } catch (_) {}
        await prefs.remove(_pendingRideNotificationOpenKey);
        _pendingRideHandlerInvoked = false;
      }

      final pendingActionRaw =
          prefs.getString(_pendingRideNotificationActionKey);
      if (pendingActionRaw != null && pendingActionRaw.isNotEmpty) {
        _pendingRideActionInvoked = false;
        _launchedFromRideRequestNotification = true;
      }
    } catch (_) {}

    processPendingRideRequestOpen();
    processPendingRideRequestAction();
  }

  /// Captures notification/FCM launch payloads before [runApp] so cold-start
  /// routing can skip splash when the driver opened a ride-request alert.
  static Future<void> captureLaunchPayloadIfNeeded() async {
    if (_launchPayloadCaptured || kIsWeb) return;

    await ensureLocalNotificationsReady(attachTapHandler: true);
    await _captureNativeRideRequestLaunchFlags();
    await _captureLaunchNotificationPayloads();
    _launchPayloadCaptured = true;
  }

  /// Reads flags stashed by native ride-request notification actions.
  static Future<void> _captureNativeRideRequestLaunchFlags() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_nativeOpenHomeForRideLaunchKey) == true) {
        _launchedFromRideRequestNotification = true;
        await prefs.remove(_nativeOpenHomeForRideLaunchKey);
      }

      final pendingOpen = prefs.getString(_pendingRideNotificationOpenKey);
      if (pendingOpen != null && pendingOpen.isNotEmpty) {
        try {
          final decoded = jsonDecode(pendingOpen);
          if (decoded is Map) {
            final data = Map<String, dynamic>.from(decoded);
            _rememberRideRequestId(data);
            _stashLaunchNotificationData(data);
          }
        } catch (_) {}
        await prefs.remove(_pendingRideNotificationOpenKey);
      }
    } catch (_) {}
  }

  /// Drops a stashed Accept/Ignore action from a previous session so a normal
  /// cold start is not hijacked by stale notification state.
  static Future<void> clearStaleNotificationActionsOnNormalLaunch() async {
    if (shouldOpenHomeForRideLaunch || kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingRideNotificationActionKey);
      await prefs.remove(_pendingRideNotificationOpenKey);
      if (Platform.isAndroid || Platform.isIOS) {
        await prefs.remove(_nativeOpenHomeForRideLaunchKey);
      }
    } catch (_) {}
  }

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    _setupNativeNotificationChannelHandlers();
    await _requestPermissions();
    _permissionsReady = true;
    await RideRequestSoundService.ensureInitialized();
    await _initializeLocalNotifications();
    if (!_launchPayloadCaptured) {
      await _captureNativeRideRequestLaunchFlags();
      await _captureLaunchNotificationPayloads();
      _launchPayloadCaptured = true;
    }

    // onBackgroundMessage is registered in app_bootstrap before runApp.

    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleForegroundMessage(message));
    });

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
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

  static void _setupNativeNotificationChannelHandlers() {
    if (kIsWeb) return;

    _rideNotificationsChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onFcmTokenRefresh':
          unawaited(registerTokenIfLoggedIn(force: true));
          return null;
        default:
          return null;
      }
    });
  }

  static Future<void> registerTokenIfLoggedIn({bool force = false}) async {
    if (kIsWeb || !AuthService.isLoggedIn) return;
    if (!_initialized && !_permissionsReady && !force) {
      _scheduleIosTokenRetry();
      return;
    }

    try {
      if (Platform.isIOS) {
        final hasApnsToken = await _ensureIosApnsToken();
        if (!hasApnsToken) {
          logNotificationIssue(
            'APNs token unavailable; scheduling FCM registration retry',
          );
          _scheduleIosTokenRetry();
          return;
        }
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        logNotificationIssue('FCM token is null or empty');
        _scheduleIosTokenRetry();
        return;
      }

      _iosTokenRetryAttempts = 0;
      _iosTokenRetryTimer?.cancel();

      final deviceInfo = await _getDeviceInfo();
      final result = await AuthService.registerFcmToken(
        deviceToken: token,
        deviceType: deviceInfo['device_type']!,
        deviceId: deviceInfo['device_id'],
      );
      if (result['success'] != true) {
        logNotificationIssue(
          'register-fcm-token failed: ${result['error']}',
        );
      }
    } on FirebaseException catch (e, stackTrace) {
      if (e.plugin == 'firebase_messaging' &&
          e.code == 'apns-token-not-set') {
        logNotificationIssue('FCM token error: apns-token-not-set', e, stackTrace);
        _scheduleIosTokenRetry();
        return;
      }
      logNotificationIssue(
        'FCM token error: ${e.code} ${e.message}',
        e,
        stackTrace,
      );
    } catch (e, stackTrace) {
      logNotificationIssue('FCM token error: $e', e, stackTrace);
      _scheduleIosTokenRetry();
    }
  }

  static void _scheduleIosTokenRetry() {
    if (kIsWeb || !Platform.isIOS || !AuthService.isLoggedIn) return;
    if (_iosTokenRetryAttempts >= 12) return;

    _iosTokenRetryTimer?.cancel();
    _iosTokenRetryAttempts++;
    final delaySeconds = _iosTokenRetryAttempts <= 4 ? 5 : 10;
    _iosTokenRetryTimer = Timer(Duration(seconds: delaySeconds), () {
      unawaited(registerTokenIfLoggedIn(force: true));
    });
  }

  static Future<void> _registerForRemoteNotificationsNative() async {
    if (!Platform.isIOS) return;
    try {
      await _rideNotificationsChannel.invokeMethod<void>(
        'registerForRemoteNotifications',
      );
    } catch (e, st) {
      logNotificationIssue(
        'Native registerForRemoteNotifications failed',
        e,
        st,
      );
    }
  }

  /// Registers for APNs before Firebase phone verification on iOS.
  static Future<void> prepareIosForPhoneAuth() async {
    if (kIsWeb || !Platform.isIOS) return;

    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    await _registerForRemoteNotificationsNative();
  }

  static Future<bool> wasNativeRideRequestRecentlyShown(String rideId) async {
    if (rideId.isEmpty) return false;

    if (Platform.isIOS) {
      try {
        final shown = await _rideNotificationsChannel.invokeMethod<bool>(
          'wasNativeRideRequestRecentlyShown',
          {'rideId': rideId},
        );
        if (shown == true) return true;
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final shownAt = prefs.getDouble('$_nativeRideAlertShownPrefix$rideId');
      if (shownAt == null) return false;
      return DateTime.now().millisecondsSinceEpoch / 1000 - shownAt < 40;
    } catch (_) {
      return false;
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
    final type = data['type']?.toString().trim().toLowerCase();
    final notificationType =
        data['notification_type']?.toString().trim().toLowerCase();
    return type == 'new_ride_request' ||
        notificationType == 'new_ride_request';
  }

  static bool isRideCancellationNotification(Map<String, dynamic> data) {
    final rideId = data['ride_id']?.toString() ?? data['id']?.toString();
    if (rideId == null || rideId.isEmpty) return false;

    final type = data['type']?.toString().trim().toLowerCase();
    final notificationType =
        data['notification_type']?.toString().trim().toLowerCase();
    if (type == 'ride_cancelled' ||
        type == 'ride_canceled' ||
        type == 'ride_cancelled_by_rider' ||
        type == 'cancelled_ride' ||
        notificationType == 'ride_cancelled' ||
        notificationType == 'ride_canceled') {
      return true;
    }

    final status = data['status']?.toString().trim().toLowerCase();
    return status == 'cancelled' || status == 'canceled';
  }

  /// Logs notification pipeline issues in release builds (visible via logcat).
  static void logNotificationIssue(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    debugPrint('PushNotificationService: $message');
    if (error != null) {
      debugPrint('PushNotificationService error: $error');
    }
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }

  /// Resolves ride-request FCM payloads even when [type] is missing from data.
  ///
  /// Backend should send **data-only** FCM for ride requests (no notification
  /// block) so the OS does not show a plain duplicate alert without actions:
  /// ```json
  /// { "data": { "type": "new_ride_request", "ride_id": "...", ... } }
  /// ```
  static Map<String, dynamic>? resolveRideRequestPayload(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    if (!isNotificationForDriver(data) || isIncomingCall(data)) {
      return null;
    }

    if (isRideRequestNotification(data)) {
      return _normalizeRideRequestPayload(data, message);
    }

    final rideId = data['ride_id']?.toString() ?? data['id']?.toString();
    if (rideId != null && rideId.isNotEmpty) {
      final status = data['status']?.toString().trim().toLowerCase();
      if (status == null ||
          status.isEmpty ||
          status == 'requested' ||
          status == 'pending') {
        return _normalizeRideRequestPayload(data, message);
      }
    }

    final notification = message.notification;
    final title = notification?.title?.trim() ??
        data['title']?.toString().trim() ??
        '';
    final body = notification?.body?.trim() ??
        data['body']?.toString().trim() ??
        data['message']?.toString().trim() ??
        '';

    if (title.isNotEmpty && _looksLikeRideRequestTitle(title)) {
      return _normalizeRideRequestPayload(
        data,
        message,
        title: title,
        body: body,
      );
    }

    if (body.isNotEmpty && _looksLikeRideRequestBody(body)) {
      return _normalizeRideRequestPayload(
        data,
        message,
        title: title,
        body: body,
      );
    }

    return null;
  }

  static bool _looksLikeRideRequestTitle(String title) {
    final trimmed = title.trim();
    if (trimmed == 'New ride request' ||
        trimmed == 'New ride request with stop(s)') {
      return true;
    }
    return RegExp(r'^New ride request from .+$').hasMatch(trimmed);
  }

  static bool _looksLikeRideRequestBody(String body) {
    return RegExp(r'^Pickup at .+ → .+$').hasMatch(body.trim());
  }

  static Map<String, dynamic> _normalizeRideRequestPayload(
    Map<String, dynamic> data,
    RemoteMessage message, {
    String? title,
    String? body,
  }) {
    final normalized = Map<String, dynamic>.from(data);
    normalized['type'] = 'new_ride_request';

    final target = normalized['target_user_type']?.toString().trim();
    if (target == null || target.isEmpty) {
      normalized['target_user_type'] = _driverUserType;
    }

    final rideId =
        normalized['ride_id']?.toString() ?? normalized['id']?.toString();
    if (rideId != null && rideId.isNotEmpty) {
      normalized['ride_id'] = rideId;
    }

    final notification = message.notification;
    final notificationTitle =
        title ?? notification?.title?.trim() ?? data['title']?.toString().trim();
    final notificationBody = body ??
        notification?.body?.trim() ??
        data['body']?.toString().trim() ??
        data['message']?.toString().trim();

    if (notificationTitle != null && notificationTitle.isNotEmpty) {
      normalized.putIfAbsent('notification_title', () => notificationTitle);
      final fromRider =
          RegExp(r'^New ride request from (.+)$').firstMatch(notificationTitle);
      if (fromRider != null) {
        normalized.putIfAbsent(
          'rider_name',
          () => fromRider.group(1)!.trim(),
        );
      }
    }

    if (notificationBody != null && notificationBody.isNotEmpty) {
      normalized.putIfAbsent('notification_body', () => notificationBody);
      final pickupMatch =
          RegExp(r'^Pickup at (.+) → (.+)$').firstMatch(notificationBody);
      if (pickupMatch != null) {
        normalized.putIfAbsent(
          'pickup_address',
          () => pickupMatch.group(1)!.trim(),
        );
        normalized.putIfAbsent(
          'dropoff_address',
          () => pickupMatch.group(2)!.trim(),
        );
      }
    }

    return normalized;
  }

  /// Invokes the ride-open handler for any pending launch payload once
  /// [onRideRequestNotificationOpened] is registered.
  static void processPendingRideRequestOpen() {
    final pending = _pendingNotificationData;
    if (pending == null || !isRideRequestNotification(pending)) return;
    if (_pendingRideHandlerInvoked) return;
    _pendingRideHandlerInvoked = true;
    unawaited(_invokeRideRequestOpenedHandler(pending));
  }

  /// Invokes a stashed Accept action once [onRideRequestNotificationAction]
  /// is registered (e.g. after cold start from a notification action).
  static void processPendingRideRequestAction() {
    if (_pendingRideActionInvoked) return;
    unawaited(_consumeAndInvokePendingRideRequestAction());
  }

  static NotificationDetails _rideRequestNotificationDetails({
    required String title,
    required String body,
    bool playSound = true,
  }) {
    final s = AppStrings.current();
    final androidDetails = AndroidNotificationDetails(
      AppConstants.rideRequestNotificationChannelId,
      'Ride Requests',
      channelDescription: 'Alerts when a new ride request is available',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: true,
      timeoutAfter: AppConstants.rideRequestAcceptDuration.inMilliseconds,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
      sound: playSound
          ? RawResourceAndroidNotificationSound(
              AppConstants.rideRequestNotificationSound,
            )
          : null,
      playSound: playSound,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      actions: [
        AndroidNotificationAction(
          AppConstants.rideRequestNotificationActionAccept,
          s.accept,
          icon: const DrawableResourceAndroidBitmap('ic_ride_action_accept'),
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          AppConstants.rideRequestNotificationActionIgnore,
          s.cancel,
          icon: const DrawableResourceAndroidBitmap('ic_ride_action_cancel'),
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      sound: playSound
          ? '${AppConstants.rideRequestNotificationSound}.wav'
          : null,
      categoryIdentifier: AppConstants.rideRequestNotificationCategoryId,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  static InitializationSettings _localNotificationInitSettings({
    required bool attachTapHandler,
  }) {
    final s = AppStrings.current();
    return InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        notificationCategories: [
          DarwinNotificationCategory(
            AppConstants.rideRequestNotificationCategoryId,
            actions: [
              DarwinNotificationAction.plain(
                AppConstants.rideRequestNotificationActionAccept,
                s.accept,
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                AppConstants.rideRequestNotificationActionIgnore,
                s.cancel,
                options: {DarwinNotificationActionOption.destructive},
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.isIOS &&
        settings.authorizationStatus != AuthorizationStatus.denied) {
      await _registerForRemoteNotificationsNative();
    }

    if (Platform.isAndroid) {
      final plugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.requestNotificationsPermission();
      await plugin?.requestFullScreenIntentPermission();
    }
  }

  /// Safe to call from the FCM background isolate and the main isolate.
  static Future<void> ensureLocalNotificationsReady({
    bool attachTapHandler = false,
  }) async {
    if (_localNotificationsReady) {
      if (Platform.isAndroid) {
        await _createAndroidChannels();
      }
      return;
    }

    await _localNotifications.initialize(
      _localNotificationInitSettings(attachTapHandler: attachTapHandler),
      onDidReceiveNotificationResponse: attachTapHandler
          ? (response) {
              unawaited(_onLocalNotificationResponse(response));
            }
          : null,
      onDidReceiveBackgroundNotificationResponse:
          rideRequestNotificationBackgroundResponse,
    );

    if (Platform.isAndroid) {
      await _createAndroidChannels();
    }
    _localNotificationsReady = true;
  }

  static Future<void> _createAndroidChannels() async {
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

  static Future<void> _initializeLocalNotifications() async {
    await ensureLocalNotificationsReady(attachTapHandler: true);
  }

  static Future<void> _captureLaunchNotificationPayloads() async {
    try {
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final response = launchDetails!.notificationResponse;
        final payload = response?.payload;
        if (payload != null && payload.isNotEmpty) {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            final data = Map<String, dynamic>.from(decoded);
            final actionId = response?.actionId;
            if (_isRideRequestNotificationAction(actionId)) {
              if (actionId == AppConstants.rideRequestNotificationActionAccept) {
                _launchedFromRideRequestNotification = true;
                _pendingRideHandlerInvoked = true;
                _pendingRideActionInvoked = false;
                unawaited(_stashPendingRideRequestAction(actionId!, data));
              } else if (actionId == AppConstants.rideRequestNotificationActionIgnore) {
                unawaited(_performBackgroundRideDecline(data));
              }
              return;
            }
            _stashLaunchNotificationData(data);
          }
        }
      }
    } catch (_) {}

    try {
      if (_initialMessageConsumed) return;

      final message = await _messaging.getInitialMessage();
      _initialMessageConsumed = true;
      if (message != null) {
        final resolved = resolveRideRequestPayload(message);
        _stashLaunchNotificationData(
          resolved ?? Map<String, dynamic>.from(message.data),
        );
      }
    } catch (_) {
      _initialMessageConsumed = true;
    }
  }

  static void _stashLaunchNotificationData(Map<String, dynamic> data) {
    if (!isNotificationForDriver(data)) return;
    _pendingNotificationData = data;
    if (isRideRequestNotification(data)) {
      _launchedFromRideRequestNotification = true;
      _pendingRideHandlerInvoked = false;
    }
  }

  static void _markAppReady() {
    if (_isAppReady) return;
    _isAppReady = true;
    _setupNotificationOpenHandlers();

    final pending = _pendingNotificationData;
    if (pending == null) return;

    // Home opens directly on ride-request cold start; HomeView consumes the
    // pending payload via processPendingRideNotificationHandlers().
    if (_launchedFromRideRequestNotification &&
        isRideRequestNotification(pending)) {
      return;
    }

    _pendingNotificationData = null;
    _processNotificationData(pending);
  }

  static Future<void> showRideRequestNotification({
    required Map<String, dynamic> data,
    bool playSound = true,
  }) async {
    // Android ride requests are shown natively with Accept/Cancel buttons.
    if (Platform.isAndroid) return;

    final rideId = data['ride_id']?.toString() ?? '';
    if (Platform.isIOS && await wasNativeRideRequestRecentlyShown(rideId)) {
      return;
    }
    final pickupAddress = data['pickup_address']?.toString() ?? '';
    final dropoffAddress = data['dropoff_address']?.toString() ?? '';
    final riderName = data['rider_name']?.toString();
    final fallbackTitle = data['notification_title']?.toString().trim();
    final fallbackBody = data['notification_body']?.toString().trim();
    final s = AppStrings.current();
    final hasRouteDetails =
        pickupAddress.isNotEmpty || dropoffAddress.isNotEmpty;
    final title = hasRouteDetails
        ? s.newRideRequestTitle(riderName: riderName)
        : (fallbackTitle != null && fallbackTitle.isNotEmpty
            ? fallbackTitle
            : s.newRideRequestTitle(riderName: riderName));
    final body = hasRouteDetails
        ? s.newRideRequestBody(
            pickupAddress: pickupAddress,
            dropoffAddress: dropoffAddress,
          )
        : (fallbackBody != null && fallbackBody.isNotEmpty
            ? fallbackBody
            : s.newRideRequestBody(
                pickupAddress: pickupAddress,
                dropoffAddress: dropoffAddress,
              ));

    final payload = Map<String, dynamic>.from(data);
    payload['type'] = 'new_ride_request';
    payload['target_user_type'] = _driverUserType;
    if (rideId.isNotEmpty) {
      payload['ride_id'] = rideId;
    }

    final notificationId = rideId.isEmpty ? data.hashCode : rideId.hashCode;
    try {
      await _localNotifications.show(
        notificationId,
        title,
        body,
        _rideRequestNotificationDetails(
          title: title,
          body: body,
          playSound: playSound,
        ),
        payload: jsonEncode(payload),
      );
    } catch (e, st) {
      logNotificationIssue('showRideRequestNotification failed', e, st);
      rethrow;
    }
  }

  static Future<void> cancelRideRequestNotification(String rideId) async {
    await _cancelRideRequestNotification(rideId);
  }

  /// Shows the in-app accept panel and plays a single alert while foregrounded.
  /// Also posts a silent tray notification with Accept/Cancel action buttons.
  static Future<void> _deliverForegroundRideRequest(
    Map<String, dynamic> data,
  ) async {
    _rememberRideRequestId(data);
    final rideId = data['ride_id']?.toString() ?? '';
    if (rideId.isNotEmpty) {
      unawaited(RideRequestSoundService.play(rideId));
    }
    await _invokeRideRequestOpenedHandler(data);
    if (Platform.isIOS) {
      if (await wasNativeRideRequestRecentlyShown(rideId)) return;
      try {
        await _rideNotificationsChannel.invokeMethod<bool>(
          'showRideRequestNotification',
          data,
        );
      } catch (e, st) {
        logNotificationIssue(
          'Native foreground ride-request notification failed',
          e,
          st,
        );
        unawaited(showRideRequestNotification(data: data, playSound: false));
      }
      return;
    }
    unawaited(showRideRequestNotification(data: data, playSound: false));
  }

  static Future<void> _cancelRideRequestNotification(String rideId) async {
    if (rideId.isEmpty) return;
    try {
      await _rideNotificationsChannel.invokeMethod<void>(
        'cancelRideRequest',
        {'rideId': rideId},
      );
    } catch (_) {}
    if (Platform.isAndroid) return;
    await _localNotifications.cancel(rideId.hashCode);
  }

  static Future<void> _onLocalNotificationResponse(
    NotificationResponse response,
  ) async {
    await RideRequestSoundService.stop();

    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    if (!isNotificationForDriver(data)) return;

    if (isRideRequestNotification(data)) {
      final actionId = response.actionId;
      if (_isRideRequestNotificationAction(actionId)) {
        await _handleRideRequestNotificationAction(actionId!, data);
        return;
      }
    }

    _handleNotificationData(data);
  }

  static Future<void> handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (_) {}

    try {
      await AppLocaleService.instance.load();
    } catch (_) {}

    try {
      await AuthService.loadStoredSession();
    } catch (_) {}

    await RideRequestSoundService.stop();

    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    if (!isNotificationForDriver(data) || !isRideRequestNotification(data)) {
      return;
    }

    final actionId = response.actionId;
    if (!_isRideRequestNotificationAction(actionId)) {
      _stashLaunchNotificationData(data);
      return;
    }

    await _performRideRequestNotificationAction(actionId!, data);
  }

  static bool _isRideRequestNotificationAction(String? actionId) {
    if (actionId == null || actionId.isEmpty) return false;
    return actionId == AppConstants.rideRequestNotificationActionAccept ||
        actionId == AppConstants.rideRequestNotificationActionIgnore;
  }

  static Future<void> _handleRideRequestNotificationAction(
    String actionId,
    Map<String, dynamic> data,
  ) async {
    _rememberRideRequestId(data);
    final rideId = data['ride_id']?.toString() ?? '';
    await stopAllRideRequestAlerts(rideId: rideId);

    if (actionId == AppConstants.rideRequestNotificationActionAccept) {
      _launchedFromRideRequestNotification = true;
      _pendingRideHandlerInvoked = true;
      _navigateToHome();
    }

    await _performRideRequestNotificationAction(actionId, data);
  }

  static Future<void> _performRideRequestNotificationAction(
    String actionId,
    Map<String, dynamic> data,
  ) async {
    final handler = onRideRequestNotificationAction;
    if (handler != null) {
      _pendingRideActionInvoked = true;
      await handler(actionId, data);
      return;
    }

    if (actionId == AppConstants.rideRequestNotificationActionAccept) {
      await _performBackgroundRideAccept(data);
      await _stashPendingRideRequestAction(actionId, data);
      return;
    }

    if (actionId == AppConstants.rideRequestNotificationActionIgnore) {
      await _performBackgroundRideDecline(data);
    }
  }

  static Future<void> _performBackgroundRideAccept(
    Map<String, dynamic> data,
  ) async {
    final rideId = data['ride_id']?.toString();
    if (rideId == null || rideId.isEmpty || !AuthService.isLoggedIn) return;

    double? latitude;
    double? longitude;
    try {
      final location = await LocationTrackerService.getCurrentLocation(
        requestPermissionIfNeeded: false,
      );
      if (location.isSuccess) {
        latitude = location.location!.latitude;
        longitude = location.location!.longitude;
      }
    } catch (_) {}

    final response = await AuthService.rideResponse(
      rideId: rideId,
      action: 'accept',
      latitude: latitude,
      longitude: longitude,
    );

    if (response['success'] != true) return;

    final offer = NearbyRideOffer.fromNotificationData(data);
    if (offer != null) {
      await ActiveRideStorage.save(offer);
    }
  }

  static Future<void> _performBackgroundRideDecline(
    Map<String, dynamic> data,
  ) async {
    final rideId = data['ride_id']?.toString();
    if (rideId == null || rideId.isEmpty || !AuthService.isLoggedIn) return;

    await AuthService.rideResponse(rideId: rideId, action: 'decline');
  }

  static Future<void> _stashPendingRideRequestAction(
    String action,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingRideNotificationActionKey,
        jsonEncode({'action': action, 'data': data}),
      );
    } catch (_) {}
  }

  static Future<void> _consumeAndInvokePendingRideRequestAction() async {
    if (_isConsumingPendingRideAction) return;
    _isConsumingPendingRideAction = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingRideNotificationActionKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await prefs.remove(_pendingRideNotificationActionKey);
        return;
      }

      final action = decoded['action']?.toString();
      final payload = decoded['data'];
      if (action == null ||
          action.isEmpty ||
          !_isRideRequestNotificationAction(action) ||
          payload is! Map) {
        await prefs.remove(_pendingRideNotificationActionKey);
        return;
      }

      final data = Map<String, dynamic>.from(payload);
      if (!isRideRequestNotification(data)) {
        await prefs.remove(_pendingRideNotificationActionKey);
        return;
      }

      _rememberRideRequestId(data);
      await prefs.remove(_pendingRideNotificationActionKey);
      await stopAllRideRequestAlerts(rideId: data['ride_id']?.toString());

      _pendingRideActionInvoked = true;
      if (action == AppConstants.rideRequestNotificationActionAccept) {
        _launchedFromRideRequestNotification = true;
        _navigateToHome();
      }

      await _invokeRideRequestActionHandler(action, data);
    } catch (_) {}
    finally {
      _isConsumingPendingRideAction = false;
    }
  }

  static Future<void> _invokeRideRequestActionHandler(
    String action,
    Map<String, dynamic> data,
  ) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final handler = onRideRequestNotificationAction;
      if (handler != null) {
        await handler(action, data);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    await _performRideRequestNotificationAction(action, data);
  }

  static Future<void> showLocalNotificationForMessage(
    RemoteMessage message,
  ) async {
    final ridePayload = resolveRideRequestPayload(message);
    if (ridePayload != null) {
      await showRideRequestNotification(data: ridePayload);
      return;
    }

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

    const details = NotificationDetails(
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
      final resolved =
          resolveRideRequestPayload(message) ??
              Map<String, dynamic>.from(message.data);
      if (!isNotificationForDriver(resolved)) return;
      _handleNotificationData(resolved);
    });

    if (_initialMessageConsumed) return;

    unawaited(
      _messaging.getInitialMessage().then((message) {
        _initialMessageConsumed = true;
        if (message == null) return;
        final resolved =
            resolveRideRequestPayload(message) ??
                Map<String, dynamic>.from(message.data);
        if (!isNotificationForDriver(resolved)) return;
        Future.delayed(const Duration(milliseconds: 100), () {
          _handleNotificationData(resolved);
        });
      }),
    );
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!isNotificationForDriver(message.data)) return;

    if (isIncomingCall(message.data)) {
      _handleIncomingCall(Map<String, dynamic>.from(message.data));
      return;
    }

    final ridePayload = resolveRideRequestPayload(message);
    if (ridePayload != null) {
      if (_isAppReady) {
        unawaited(_deliverForegroundRideRequest(ridePayload));
      } else {
        _handleNotificationData(ridePayload);
      }
      return;
    }

    final cancellationData = Map<String, dynamic>.from(message.data);
    if (isRideCancellationNotification(cancellationData)) {
      if (_isAppReady) {
        unawaited(_invokeRideCancelledHandler(cancellationData));
      } else {
        _handleNotificationData(cancellationData);
      }
      return;
    }

    await showLocalNotificationForMessage(message);
  }

  static void _handleNotificationData(Map<String, dynamic> data) {
    if (!_isAppReady) {
      _pendingNotificationData = data;
      if (isRideRequestNotification(data)) {
        _launchedFromRideRequestNotification = true;
        _pendingRideHandlerInvoked = false;
      }
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

    if (isRideCancellationNotification(data)) {
      unawaited(_invokeRideCancelledHandler(data));
      return;
    }

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamed(AppRoutes.notifications);
  }

  static void _openRideRequestFromNotification(Map<String, dynamic> data) {
    _rememberRideRequestId(data);
    unawaited(stopAllRideRequestAlerts(rideId: data['ride_id']?.toString()));
    if (!_pendingRideHandlerInvoked) {
      _pendingRideHandlerInvoked = true;
      unawaited(_invokeRideRequestOpenedHandler(data));
    }
    _navigateToHome();
  }

  static void _navigateToHome() {
    void navigate() {
      final nav = appNavigatorKey.currentState;
      if (nav == null) return;

      var onHome = false;
      nav.popUntil((route) {
        onHome = route.settings.name == AppRoutes.home;
        return onHome || route.isFirst;
      });
      if (onHome) return;

      // Cold-start already opened Home as the sole root route.
      if (_launchedFromRideRequestNotification && !nav.canPop()) {
        return;
      }

      nav.pushNamed(AppRoutes.home);
    }

    SchedulerBinding.instance.addPostFrameCallback((_) => navigate());
  }

  static Future<void> _invokeRideRequestOpenedHandler(
    Map<String, dynamic> data,
  ) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final handler = onRideRequestNotificationOpened;
      if (handler != null) {
        await handler(data);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  static Future<void> _invokeRideCancelledHandler(
    Map<String, dynamic> data,
  ) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final handler = onRideCancelledNotification;
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
    for (var attempt = 0; attempt < 60; attempt++) {
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
