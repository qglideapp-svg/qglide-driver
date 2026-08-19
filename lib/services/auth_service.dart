import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/api_config.dart';
import '../config/app_strings.dart';
import '../features/splash/splash_video_model.dart';
import 'app_locale_service.dart';
import 'apple_sign_in_service.dart';
import '../features/home/models/deposit_payment.dart';
import '../features/home/models/driver_completed_trip.dart';
import '../features/home/models/driver_ride_details.dart';
import '../features/home/models/driver_wallet_balance.dart';
import '../features/home/models/driver_referral_progress.dart';
import '../features/home/models/signup_performance_bonus.dart';
import '../features/ride/call/models/zego_call_session.dart';
import '../features/notifications/models/driver_notification.dart';
import '../features/profile/models/support_ticket.dart';
import '../features/auth/document_upload/driver_document_type.dart';
import '../features/auth/verification/verification_args.dart';
import '../routes/app_routes.dart';
import 'driver_status_service.dart';
import 'phone_verification_service.dart';
import 'screen_wake_service.dart';
import 'secure_session_storage.dart';

class OAuthSignupPrefill {
  const OAuthSignupPrefill({
    this.fullName,
    this.email,
    this.phone,
  });

  final String? fullName;
  final String? email;
  final String? phone;

  Map<String, dynamic> toJson() => {
        if (fullName != null) 'full_name': fullName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
      };
}

class AuthService {
  AuthService._();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenExpiresAtKey = 'token_expires_at';
  static const _onboardingCompletedKey = 'onboarding_completed';
  static const _pendingVerificationPhoneKey = 'pending_verification_phone';
  static const _pendingVerificationEmailKey = 'pending_verification_email';
  static const _pendingVerificationFirebasePhoneE164Key =
      'pending_verification_firebase_phone_e164';
  static const _pendingSignupPasswordKey = 'pending_signup_password';
  static const _signupBootstrapEmailKey = 'signup_bootstrap_email';
  static const _signupBootstrapPasswordKey = 'signup_bootstrap_password';
  static const _signupResumeRouteKey = 'signup_resume_route_v2';
  static const _signupResumePhoneVerifiedKey = 'signup_resume_phone_verified';
  static const _referralCodeKey = 'referral_code';
  static const _referralActiveKey = 'referral_active';
  static const _referralRepollEmailKey = 'referral_repoll_email';
  static const _referralRepollPasswordKey = 'referral_repoll_password';
  static const _nativeNotificationAccessTokenKey =
      'native_notification_access_token';
  static const _refreshLeadTime = Duration(minutes: 5);
  static const _sessionRefreshInterval = Duration(minutes: 20);

  static String? _accessToken;
  static String? _refreshToken;
  static DateTime? _tokenExpiresAt;
  static var _onboardingCompleted = false;
  static var shouldRefreshHomeWallet = false;
  static DriverWalletBalance? _prefetchedWalletBalance;
  static String? _referralCode;
  static var _referralActive = false;
  static var _prefsUnavailable = false;
  static Timer? _refreshTimer;
  static Future<bool>? _refreshFuture;

  static String? get accessToken => _accessToken;
  static bool get isLoggedIn =>
      _accessToken != null && _accessToken!.isNotEmpty;
  static bool get isAccessTokenExpired {
    if (_accessToken == null || _accessToken!.isEmpty) return true;
    final expiresAt = _tokenExpiresAt ?? _accessTokenExpiryFromJwt();
    if (expiresAt == null) return true;
    return !DateTime.now().toUtc().isBefore(expiresAt);
  }
  static bool get hasValidSession => isLoggedIn && !isAccessTokenExpired;
  static bool get hasStoredSession =>
      isLoggedIn || (_refreshToken != null && _refreshToken!.isNotEmpty);
  static bool get hasCompletedOnboarding => _onboardingCompleted;
  static String? get referralCode => _referralCode;
  static bool get referralActive => _referralActive;
  static bool get canShowReferDriver {
    final code = _referralCode?.trim();
    return code != null && code.isNotEmpty;
  }

  static Future<SharedPreferences?> _prefs() async {
    if (_prefsUnavailable) return null;
    try {
      return await SharedPreferences.getInstance();
    } catch (error) {
      _prefsUnavailable = true;
      return null;
    }
  }

  /// Reads persisted session fields from disk only — no network refresh.
  static Future<void> loadStoredSessionFromDisk() async {
    final prefs = await _prefs();

    final snapshot = await SecureSessionStorage.read(prefs: prefs);
    _accessToken = snapshot.accessToken;
    _refreshToken = snapshot.refreshToken;
    if (snapshot.expiresAtMs != null) {
      _tokenExpiresAt = DateTime.fromMillisecondsSinceEpoch(
        snapshot.expiresAtMs!,
        isUtc: true,
      );
    } else {
      _tokenExpiresAt = null;
    }

    await _mirrorNativeNotificationAccessToken(_accessToken);

    if (prefs == null) return;

    _onboardingCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;

    _referralCode = prefs.getString(_referralCodeKey);
    final storedReferralActive = prefs.getBool(_referralActiveKey);
    _referralActive = storedReferralActive ??
        (_referralCode != null && _referralCode!.trim().isNotEmpty);
  }

  static Future<void> loadStoredSession() async {
    await loadStoredSessionFromDisk();
    await ensureSessionRestored();

    if (isLoggedIn) {
      unawaited(ensureReferralSynced());
    }
  }

  /// Restores a logged-in session on cold start, refreshing if needed.
  static Future<void> ensureSessionRestored() async {
    final hasRefreshToken =
        _refreshToken != null && _refreshToken!.isNotEmpty;
    if (hasRefreshToken && (!isLoggedIn || isAccessTokenExpired)) {
      await refreshSessionIfNeeded(force: true);
    }

    if (!hasValidSession && (isLoggedIn || hasRefreshToken)) {
      await _tryRecoverExpiredSession();
    }

    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      startSessionRefresh();
    }
  }

  static Future<void> markOnboardingCompleted() async {
    _onboardingCompleted = true;
    final prefs = await _prefs();
    await prefs?.setBool(_onboardingCompletedKey, true);
  }

  static Future<void> savePendingVerificationContext({
    required String phone,
    required String email,
    String? password,
    String countryCode = ApiConfig.defaultCountryCode,
    String? firebasePhoneE164,
  }) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final normalized = normalizeDriverPhone(
      phone: phone,
      countryCode: countryCode,
    );
    if (normalized.isEmpty) return;
    await prefs.setString(_pendingVerificationPhoneKey, normalized);
    await prefs.setString(_pendingVerificationEmailKey, email.trim());
    final trimmedFirebasePhone = firebasePhoneE164?.trim();
    if (trimmedFirebasePhone != null && trimmedFirebasePhone.isNotEmpty) {
      await prefs.setString(
        _pendingVerificationFirebasePhoneE164Key,
        trimmedFirebasePhone,
      );
    } else {
      await prefs.remove(_pendingVerificationFirebasePhoneE164Key);
    }
    if (password != null && password.isNotEmpty) {
      await prefs.setString(_pendingSignupPasswordKey, password);
      await prefs.setString(_signupBootstrapEmailKey, email.trim());
      await prefs.setString(_signupBootstrapPasswordKey, password);
    }
  }

  static Future<void> saveSignupBootstrapCredentials({
    required String email,
    required String password,
  }) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) return;
    await prefs.setString(_signupBootstrapEmailKey, trimmedEmail);
    await prefs.setString(_signupBootstrapPasswordKey, password);
    await prefs.setString(_pendingVerificationEmailKey, trimmedEmail);
    await prefs.setString(_pendingSignupPasswordKey, password);
  }

  static Future<void> clearSignupBootstrapCredentials() async {
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.remove(_signupBootstrapEmailKey);
    await prefs.remove(_signupBootstrapPasswordKey);
  }

  static Future<void> markSignupResumeAfterPhoneVerification() async {
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.setBool(_signupResumePhoneVerifiedKey, true);
  }

  static Future<bool> hasCompletedPhoneVerificationResume() async {
    final prefs = await _prefs();
    if (prefs == null) return false;
    return prefs.getBool(_signupResumePhoneVerifiedKey) == true;
  }

  static Future<DriverAccessRoute?> loadSignupResumeRoute() async {
    final prefs = await _prefs();
    if (prefs == null) return null;
    if (prefs.getBool(_signupResumePhoneVerifiedKey) != true) return null;
    final stored = prefs.getString(_signupResumeRouteKey);
    if (stored == null || stored.isEmpty) return null;
    for (final route in DriverAccessRoute.values) {
      if (route.name == stored) return route;
    }
    return null;
  }

  static Future<void> clearSignupResumeRoute() async {
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.remove(_signupResumeRouteKey);
    await prefs.remove(_signupResumePhoneVerifiedKey);
  }

  static Future<VerificationArgs?> loadPendingVerificationContext() async {
    final prefs = await _prefs();
    if (prefs == null) return null;
    final phone = prefs.getString(_pendingVerificationPhoneKey)?.trim();
    if (phone == null || phone.isEmpty) return null;
    final email = prefs.getString(_pendingVerificationEmailKey)?.trim();
    final firebasePhoneE164 =
        prefs.getString(_pendingVerificationFirebasePhoneE164Key)?.trim();
    final args = VerificationArgs.fromPhone(
      phone: phone,
      email: email,
      firebasePhoneE164: firebasePhoneE164,
    );
    if (!args.hasValidPhone) {
      await clearPendingVerificationContext();
      return null;
    }
    return args;
  }

  static Future<void> clearStaleDriverProgress() async {
    await DriverStatusService.clearStored();
  }

  static Future<void> clearStaleSignupProgress() async {
    await clearStaleDriverProgress();
    await clearPendingVerificationContext();
  }

  static Future<void> clearPendingPhoneContext() async {
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.remove(_pendingVerificationPhoneKey);
    await prefs.remove(_pendingVerificationFirebasePhoneE164Key);
  }

  static Future<void> clearPendingSignupCredentials() async {
    final prefs = await _prefs();
    if (prefs == null) return;
    await prefs.remove(_pendingVerificationEmailKey);
    await prefs.remove(_pendingSignupPasswordKey);
  }

  static Future<void> clearPendingVerificationContext() async {
    await clearPendingPhoneContext();
    await clearPendingSignupCredentials();
    await clearSignupBootstrapCredentials();
    await clearSignupResumeRoute();
  }

  /// Clears leftover signup-funnel local state once the driver reaches the dashboard.
  static Future<void> clearCompletedSignupLocalState() async {
    await clearPendingVerificationContext();
    await PhoneVerificationService.clearPersistedVerificationSession();
  }

  static String? _readPendingSignupEmail(SharedPreferences prefs) {
    return prefs.getString(_pendingVerificationEmailKey)?.trim();
  }

  static String? _readBootstrapEmail(SharedPreferences prefs) {
    return prefs.getString(_signupBootstrapEmailKey)?.trim() ??
        _readPendingSignupEmail(prefs);
  }

  static String? _readBootstrapPassword(SharedPreferences prefs) {
    return prefs.getString(_signupBootstrapPasswordKey) ??
        prefs.getString(_pendingSignupPasswordKey);
  }

  static Future<bool> _hasSignupPhoneVerified([SharedPreferences? prefs]) async {
    final resolved = prefs ?? await _prefs();
    if (resolved == null) return false;
    if (resolved.getBool(_signupResumePhoneVerifiedKey) == true) return true;
    final stored = await DriverStatusService.loadStored();
    return stored?.phoneVerified == true;
  }

  /// Re-establishes a Supabase session after signup when tokens were not persisted.
  static Future<bool> bootstrapPendingSignupSession() async {
    if (isLoggedIn) return true;

    final prefs = await _prefs();
    if (prefs == null) return false;

    final email = _readBootstrapEmail(prefs);
    final password = _readBootstrapPassword(prefs);
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return false;
    }

    final phoneVerified = await _hasSignupPhoneVerified(prefs);
    if (phoneVerified) {
      final driverLoginResult = await driverLogin(
        email: email,
        password: password,
      );
      if (driverLoginResult['success'] == true && isLoggedIn) {
        return true;
      }
    }

    final result = await signInWithPassword(
      email: email,
      password: password,
    );
    return result['success'] == true && isLoggedIn;
  }

  /// Ensures a bearer token exists before protected signup/onboarding API calls.
  static Future<bool> ensureAuthenticatedSession() async {
    return recoverStoredSession();
  }

  /// Restores tokens from storage without clearing persisted credentials.
  /// Drivers remain signed in until they explicitly log out.
  static Future<bool> recoverStoredSession() async {
    await ensureSessionRestored();
    if (hasValidSession) return true;
    if (await bootstrapPendingSignupSession()) return hasValidSession;
    if (await _tryRecoverExpiredSession()) return hasValidSession;
    return hasValidSession;
  }

  static Future<bool> _reauthenticateFromStoredCredentials() async {
    final prefs = await _prefs();
    if (prefs == null) return false;

    final password = _readReferralRepollPassword(prefs) ??
        _readBootstrapPassword(prefs);
    if (password == null || password.isEmpty) return false;

    final email = _readReferralRepollEmail(prefs) ??
        _readBootstrapEmail(prefs);
    if (email == null || email.isEmpty) return false;

    final result = await driverLogin(email: email, password: password);
    return result['success'] == true && isLoggedIn;
  }

  /// Establishes a Supabase session after signup (signup API does not return tokens).
  static Future<Map<String, dynamic>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.passwordSignInUrl),
            headers: _jsonHeaders,
            body: json.encode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final result = _handleSupabaseAuthResponse(response);
      if (result['success'] == true) {
        final data = result['data'];
        if (data is Map<String, dynamic>) {
          await _persistSessionFromAuthData(data);
        }
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<void> clearAccessToken() async {
    stopSessionRefresh();
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiresAt = null;

    await SecureSessionStorage.clear();

    final prefs = await _prefs();
    await prefs?.remove(_accessTokenKey);
    await prefs?.remove(_refreshTokenKey);
    await prefs?.remove(_tokenExpiresAtKey);
    await prefs?.remove(_nativeNotificationAccessTokenKey);
    await _clearReferralState();
  }

  static Future<void> _clearReferralState() async {
    _referralCode = null;
    _referralActive = false;
    final prefs = await _prefs();
    await prefs?.remove(_referralCodeKey);
    await prefs?.remove(_referralActiveKey);
    await prefs?.remove(_referralRepollEmailKey);
    await prefs?.remove(_referralRepollPasswordKey);
  }

  static Future<void> _saveReferralRepollCredentials({
    required String email,
    required String password,
  }) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) return;
    await prefs.setString(_referralRepollEmailKey, trimmedEmail);
    await prefs.setString(_referralRepollPasswordKey, password);
  }

  static String? _readReferralRepollEmail(SharedPreferences prefs) {
    return prefs.getString(_referralRepollEmailKey)?.trim();
  }

  static String? _readReferralRepollPassword(SharedPreferences prefs) {
    return prefs.getString(_referralRepollPasswordKey);
  }

  static Future<void> invalidateStoredSession() async {
    await clearAccessToken();
    await _clearGoogleSignInSession();
  }

  static Future<void> signOut() async {
    await ScreenWakeService.disable();
    await invalidateStoredSession();
    await DriverStatusService.clearStored();
    await clearPendingVerificationContext();
    await PhoneVerificationService.clearPersistedVerificationSession();
  }

  static bool isUnauthorizedResponse(Map<String, dynamic> response) {
    if (response['success'] == true) return false;

    final error = response['error'];
    if (error == null) return false;

    if (error is Map && error['success'] == false && error['error'] != null) {
      final nestedError = error['error'];
      if (nestedError == 'Unauthorized' ||
          nestedError.toString().contains('Unauthorized')) {
        return true;
      }
    }

    if (error == 'Unauthorized' || error.toString().contains('Unauthorized')) {
      return true;
    }

    final message = extractErrorMessage(response).toLowerCase();
    return message.contains('unauthorized') ||
        message.contains('invalid or expired token') ||
        message.contains('jwt expired') ||
        message.contains('invalid jwt') ||
        message.contains('invalid token') ||
        message.contains('token expired') ||
        message.contains('jwt malformed');
  }

  static bool isAuthErrorMessage(String? message) {
    if (message == null || message.isEmpty) return false;
    final lower = message.toLowerCase();
    return lower.contains('unauthorized') ||
        lower.contains('invalid jwt') ||
        lower.contains('invalid token') ||
        lower.contains('token expired') ||
        lower.contains('jwt expired') ||
        lower.contains('jwt malformed') ||
        lower.contains('invalid or expired token') ||
        lower.contains('not logged in') ||
        lower.contains('sign in again') ||
        lower.contains('session expired');
  }

  static String sanitizeAuthErrorMessage(String? message) {
    if (isAuthErrorMessage(message)) {
      return AppStrings.current().sessionExpiredSignInAgain;
    }
    if (message == null || message.isEmpty) {
      return AppStrings.current().sessionExpiredSignInAgain;
    }
    return message;
  }

  static bool isSessionInvalidResponse(Map<String, dynamic> response) {
    return isUserDeletedResponse(response);
  }

  static bool isUserDeletedResponse(Map<String, dynamic> response) {
    if (response['success'] == true) return false;

    final message = extractErrorMessage(response).toLowerCase();
    return message.contains('profile not found') ||
        message.contains('user profile not found') ||
        message.contains('user not found');
  }

  static bool isAccountBlockedResponse(Map<String, dynamic> response) {
    if (response['success'] == true) return false;

    final message = extractErrorMessage(response).toLowerCase();
    return message.contains('account is inactive') ||
        message.contains('account must be active') ||
        message.contains('account disabled') ||
        message.contains('account is suspended') ||
        message.contains('suspended') && message.contains('account') ||
        message.contains('inactive') && message.contains('driver');
  }

  static bool isAuthFailureResponse(Map<String, dynamic> response) {
    return isUnauthorizedResponse(response) ||
        isAccountBlockedResponse(response) ||
        isUserDeletedResponse(response);
  }

  static bool isRefreshTokenInvalidResponse(int statusCode, String body) {
    if (body.isEmpty) {
      return statusCode == 400 || statusCode == 401;
    }

    try {
      final decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) {
        return statusCode == 400 || statusCode == 401;
      }

      final error = decoded['error']?.toString().toLowerCase();
      final description =
          decoded['error_description']?.toString().toLowerCase() ?? '';
      if (error == 'invalid_grant') return true;
      if (description.contains('invalid refresh token')) return true;
      if (description.contains('refresh token not found')) return true;
      if (description.contains('token has been revoked')) return true;
      if (description.contains('account disabled')) return true;
      return statusCode == 400 || statusCode == 401;
    } catch (_) {
      final lower = body.toLowerCase();
      return lower.contains('invalid_grant') ||
          lower.contains('invalid refresh token');
    }
  }

  static bool isRetryableNetworkError(Object error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is http.ClientException) return true;
    if (error is HandshakeException) return true;
    return false;
  }

  static bool isHardSessionFailureResponse(Map<String, dynamic> response) {
    return isAuthFailureResponse(response) || isUserDeletedResponse(response);
  }

  /// Clears tokens after an unrecoverable session failure.
  static Future<void> invalidateSessionAfterHardFailure() async {
    await clearAccessToken();
  }

  /// True when refresh/re-auth failed and the user must sign in again.
  static Future<bool> requiresLoginAfterRecoveryAttempt() async {
    await loadStoredSessionFromDisk();
    await _tryRecoverExpiredSession();
    return !hasValidSession;
  }

  static Future<bool> hasPendingSignupCredentials() async {
    final prefs = await _prefs();
    if (prefs == null) return false;
    final email = _readBootstrapEmail(prefs);
    final password = _readBootstrapPassword(prefs);
    return email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  /// Uses driver-onboarding-status + get-user-profile to decide the signup funnel screen.
  static Future<DriverAccessRoute?> resolveSignupRouteFromBackend() async {
    final phoneVerifiedResume = await _hasSignupPhoneVerified();

    if (!isLoggedIn) {
      if (phoneVerifiedResume || hasStoredSession) {
        await recoverStoredSession();
      } else {
        return null;
      }
    }
    if (!isLoggedIn && !hasStoredSession) return null;

    final route = await _syncSignupStatusFromBackend();
    if (route == DriverAccessRoute.dashboard) {
      await clearCompletedSignupLocalState();
    }
    return route;
  }

  static Future<DriverAccessRoute?> _syncSignupStatusFromBackend() async {
    if (!isLoggedIn) {
      await recoverStoredSession();
    }
    if (!isLoggedIn && !hasStoredSession) return null;

    var onboardingResponse = await getDriverOnboardingStatus();
    if (isUserDeletedResponse(onboardingResponse)) {
      await signOut();
      return null;
    }
    if (isUnauthorizedResponse(onboardingResponse)) {
      await recoverStoredSession();
      onboardingResponse = await getDriverOnboardingStatus();
    }

    var profileResponse = await getUserProfile();
    if (isUserDeletedResponse(profileResponse)) {
      await signOut();
      return null;
    }
    if (isUnauthorizedResponse(profileResponse)) {
      await recoverStoredSession();
      profileResponse = await getUserProfile();
    }

    if (isUnauthorizedResponse(onboardingResponse) &&
        isUnauthorizedResponse(profileResponse)) {
      final stored = await DriverStatusService.loadStored();
      if (stored != null) {
        return DriverStatusService.resolveRoute(status: stored);
      }
      return null;
    }

    var status = DriverStatusService.merge(
      DriverStatusService.extractFromOnboarding(onboardingResponse),
      DriverStatusService.extractFromProfile(profileResponse),
    );

    final phoneVerifiedResume = await _hasSignupPhoneVerified();
    if (!phoneVerifiedResume && status?.isFullyApproved != true) {
      final stored = await DriverStatusService.loadStored();
      status = DriverStatusService.merge(status, stored);
    }

    if (status != null) {
      await DriverStatusService.persist(
        status,
        statusResponse: onboardingResponse['success'] == true
            ? onboardingResponse
            : profileResponse,
      );
    }

    return DriverStatusService.resolveRoute(status: status);
  }

  /// Verifies a restored session against the API without wiping signup progress on token expiry.
  static Future<bool> validateStoredSession() async {
    if (!hasStoredSession) {
      return false;
    }

    await ensureSessionRestored();
    if (!isLoggedIn) {
      return false;
    }

    final route = await resolveSignupRouteFromBackend();
    return isLoggedIn && route != null;
  }

  /// Where to send users with no valid session after splash.
  static String get unauthenticatedEntryRoute {
    if (hasCompletedOnboarding) return AppRoutes.signup;
    return AppRoutes.onboarding;
  }

  static String get routeAfterSplash {
    if (isLoggedIn) return AppRoutes.home;
    return unauthenticatedEntryRoute;
  }

  static String? extractAccessToken(Map<String, dynamic> payload) {
    final authData = unwrapAuthPayload(payload);
    return _extractToken(authData, 'access_token') ??
        _extractToken(authData, 'accessToken') ??
        _extractToken(authData, 'token');
  }

  static String? extractRefreshToken(Map<String, dynamic> payload) {
    final authData = unwrapAuthPayload(payload);
    return _extractToken(authData, 'refresh_token') ??
        _extractToken(authData, 'refreshToken');
  }

  static Map<String, dynamic> unwrapAuthPayload(Map<String, dynamic> payload) {
    var current = payload;
    for (var depth = 0; depth < 3; depth++) {
      if (current['session'] is Map<String, dynamic> ||
          current['access_token'] is String ||
          current['refresh_token'] is String) {
        return current;
      }

      final nested = current['data'];
      if (nested is Map<String, dynamic>) {
        current = nested;
        continue;
      }
      break;
    }
    return current;
  }

  static String? _extractToken(
    Map<String, dynamic> payload,
    String key,
  ) {
    String? asToken(dynamic value) {
      if (value is String && value.isNotEmpty) return value;
      return null;
    }

    String? fromMap(Map<String, dynamic>? map) {
      if (map == null) return null;
      return asToken(map[key]);
    }

    final session = payload['session'];
    if (session is Map<String, dynamic>) {
      final token = fromMap(session);
      if (token != null) return token;
    }

    return fromMap(payload) ??
        (payload['data'] is Map<String, dynamic>
            ? fromMap(payload['data'] as Map<String, dynamic>)
            : null);
  }

  static DateTime? _extractExpiresAt(Map<String, dynamic> payload) {
    final authData = unwrapAuthPayload(payload);
    Map<String, dynamic>? session;
    if (authData['session'] is Map<String, dynamic>) {
      session = authData['session'] as Map<String, dynamic>;
    }

    final source = session ?? authData;
    final expiresAt = source['expires_at'];
    if (expiresAt is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        expiresAt.toInt() * 1000,
        isUtc: true,
      );
    }

    final expiresIn = source['expires_in'];
    if (expiresIn is num) {
      return DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt()));
    }

    return null;
  }

  static Future<void> _persistSession({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    _accessToken = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
    if (expiresAt != null) {
      _tokenExpiresAt = expiresAt;
    }

    await SecureSessionStorage.write(
      accessToken: accessToken,
      refreshToken: _refreshToken,
      expiresAt: _tokenExpiresAt,
    );

    await _mirrorNativeNotificationAccessToken(accessToken);

    final prefs = await _prefs();
    if (prefs == null) {
      return;
    }

    // Legacy keys removed after migration; keep delete for older installs.
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_tokenExpiresAtKey);
  }

  /// Mirrors the bearer token for native Android notification Accept/Cancel.
  static Future<void> _mirrorNativeNotificationAccessToken(
    String? accessToken,
  ) async {
    final prefs = await _prefs();
    if (prefs == null) return;

    if (accessToken == null || accessToken.isEmpty) {
      await prefs.remove(_nativeNotificationAccessTokenKey);
      return;
    }

    await prefs.setString(_nativeNotificationAccessTokenKey, accessToken);
  }

  static Future<void> _persistSessionFromAuthData(
    Map<String, dynamic> data,
  ) async {
    final authData = unwrapAuthPayload(data);
    final accessToken = extractAccessToken(authData);
    final refreshToken = extractRefreshToken(authData);
    if (accessToken == null) {
      return;
    }

    await _persistSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: _extractExpiresAt(authData),
    );

    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      startSessionRefresh();
    }

    await persistReferralFromAuthPayload(authData);
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  static Future<void> _applyReferralState({
    String? referralCode,
    bool? referralActive,
  }) async {
    final prefs = await _prefs();
    if (prefs == null) return;

    final trimmed = referralCode?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      _referralCode = trimmed;
      _referralActive = true;
      await prefs.setString(_referralCodeKey, trimmed);
      await prefs.setBool(_referralActiveKey, true);
      return;
    }

    if (referralActive == true) {
      _referralActive = true;
      await prefs.setBool(_referralActiveKey, true);
    }
  }

  static String? _deepFindReferralCode(dynamic node, [int depth = 0]) {
    if (depth > 8 || node == null) return null;

    if (node is Map) {
      final direct = node['referral_code'];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct.trim();
      }
      for (final value in node.values) {
        final found = _deepFindReferralCode(value, depth + 1);
        if (found != null) return found;
      }
      return null;
    }

    if (node is List) {
      for (final item in node) {
        final found = _deepFindReferralCode(item, depth + 1);
        if (found != null) return found;
      }
    }

    return null;
  }

  static Future<void> syncReferralFromAnyResponse(
    Map<String, dynamic> response,
  ) async {
    if (response['success'] != true) return;
    final code = _deepFindReferralCode(response);
    if (code == null || code.isEmpty) return;
    await _applyReferralState(referralCode: code, referralActive: true);
  }

  static List<Map<String, dynamic>> _collectReferralNodes(
    Map<String, dynamic> root,
  ) {
    final nodes = <Map<String, dynamic>>[];
    final seen = <int>{};

    void add(Map<String, dynamic>? map) {
      if (map == null) return;
      final id = identityHashCode(map);
      if (seen.contains(id)) return;
      seen.add(id);
      nodes.add(map);
    }

    add(root);
    add(unwrapAuthPayload(root));

    final data = root['data'];
    if (data is Map<String, dynamic>) {
      add(data);
      add(unwrapAuthPayload(data));
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        add(inner);
        add(unwrapAuthPayload(inner));
      }
    }

    return nodes;
  }

  static ({String? code, bool? active}) _readReferralFields(
    Iterable<Map<String, dynamic>> nodes,
  ) {
    String? referralCode;
    bool? referralActive;

    for (final node in nodes) {
      referralCode ??= node['referral_code']?.toString();

      final account = node['account_details'];
      if (account is Map<String, dynamic>) {
        referralCode ??= account['referral_code']?.toString();
        if (account.containsKey('referral_active')) {
          referralActive ??= _readBool(account['referral_active']);
        }
      }

      if (node.containsKey('referral_active')) {
        referralActive ??= _readBool(node['referral_active']);
      }
    }

    final trimmedCode = referralCode?.trim();
    if (referralActive != true &&
        trimmedCode != null &&
        trimmedCode.isNotEmpty) {
      referralActive = true;
    }

    return (code: trimmedCode, active: referralActive);
  }

  static Future<void> persistReferralFromAuthPayload(
    Map<String, dynamic> payload,
  ) async {
    final fields = _readReferralFields(_collectReferralNodes(payload));
    final referralCode = fields.code;
    final referralActive = fields.active;

    if (referralCode == null && referralActive == null) return;

    await _applyReferralState(
      referralCode: referralCode,
      referralActive: referralActive,
    );
  }

  static Future<void> persistReferralFromAuthResponse(
    Map<String, dynamic> response,
  ) async {
    await syncReferralFromAnyResponse(response);
  }

  static Future<void> syncReferralFromProfile(
    Map<String, dynamic> response,
  ) async {
    if (response['success'] != true) return;

    final nodes = <Map<String, dynamic>>[];
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      nodes.addAll(_collectReferralNodes(data));
    }

    final profile = extractUserProfile(response);
    if (profile != null) {
      nodes.add(profile);
      final account = profile['account_details'];
      if (account is Map<String, dynamic>) {
        nodes.add(account);
      }
    }

    final fields = _readReferralFields(nodes);
    final referralCode = fields.code;
    final referralActive = fields.active;

    // Profile responses often omit referral fields; never clear a code loaded at login.
    if (referralCode == null || referralCode.isEmpty) {
      if (referralActive != true) return;
      return;
    }

    await _applyReferralState(
      referralCode: referralCode,
      referralActive: referralActive ?? true,
    );
  }

  static String? emailFromAccessToken() {
    final token = _accessToken;
    if (token == null || token.isEmpty) return null;
    final payload = decodeJwtPayload(token);
    final email = payload?['email']?.toString().trim();
    return email != null && email.isNotEmpty ? email : null;
  }

  static Future<void> syncReferralFromIncentiveProgress(
    Map<String, dynamic> response,
  ) async {
    await syncReferralFromAnyResponse(response);
  }

  /// Loads referral for an existing session without signing the user out.
  static Future<bool> ensureReferralSynced() async {
    if (canShowReferDriver) return true;
    if (!isLoggedIn) return false;

    await refreshSessionIfNeeded();

    final attempts = <Future<Map<String, dynamic>>>[
      getDriverReferralCode(),
      getDriverIncentiveProgress(),
      getUserProfile(),
    ];

    for (final attempt in attempts) {
      final response = await attempt;
      await syncReferralFromAnyResponse(response);
      if (canShowReferDriver) return true;
    }

    await _repollDriverLoginForReferral();
    return canShowReferDriver;
  }

  static Future<Map<String, dynamic>> getDriverReferralCode() async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      for (final request in <Future<http.Response> Function()>[
        () => http
            .get(
              Uri.parse(ApiConfig.driverReferralGenerateUrl),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20)),
        () => http
            .post(
              Uri.parse(ApiConfig.driverReferralGenerateUrl),
              headers: headers,
              body: json.encode({}),
            )
            .timeout(const Duration(seconds: 20)),
      ]) {
        final response = await request();
        final result = _handleResponse(response);
        if (result['success'] == true) {
          await syncReferralFromAnyResponse(result);
          return result;
        }
      }

      return {
        'success': false,
        'error': {'message': 'Referral code unavailable'},
      };
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<void> _repollDriverLoginForReferral() async {
    if (!isLoggedIn) return;

    final prefs = await _prefs();
    if (prefs == null) return;

    final password = _readReferralRepollPassword(prefs) ??
        _readBootstrapPassword(prefs);
    if (password == null || password.isEmpty) return;

    final email = _readReferralRepollEmail(prefs) ??
        _readBootstrapEmail(prefs) ??
        emailFromAccessToken();

    if (email == null || email.isEmpty) {
      final profileResponse = await getUserProfile();
      final profile = extractUserProfile(profileResponse);
      final profileEmail =
          profile != null ? extractProfileEmail(profile) : null;
      if (profileEmail == null || profileEmail.isEmpty) return;

      final result = await driverLogin(email: profileEmail, password: password);
      if (result['success'] == true) {
        await syncReferralFromAnyResponse(result);
      }
      return;
    }

    final result = await driverLogin(email: email, password: password);
    if (result['success'] == true) {
      await syncReferralFromAnyResponse(result);
    }
  }

  static void startSessionRefresh() {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return;
    }

    stopSessionRefresh();
    _refreshTimer = Timer.periodic(_sessionRefreshInterval, (_) {
      unawaited(refreshSessionIfNeeded(force: true));
    });
  }

  /// Reloads persisted tokens and re-establishes auth after idle/background.
  static Future<bool> maintainSession() async {
    await loadStoredSessionFromDisk();
    final recovered = await _tryRecoverExpiredSession();

    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      startSessionRefresh();
    }

    return recovered && hasValidSession;
  }

  /// Refreshes or silently re-authenticates when the access token is stale.
  static Future<bool> _tryRecoverExpiredSession() async {
    if (hasValidSession) return true;

    final hasRefreshToken =
        _refreshToken != null && _refreshToken!.isNotEmpty;
    if (hasRefreshToken) {
      await refreshSessionIfNeeded(force: true);
      if (hasValidSession) return true;
    }

    if (await _reauthenticateFromStoredCredentials() && hasValidSession) {
      return true;
    }
    if (await _reauthenticateFromGoogleSilently() && hasValidSession) {
      return true;
    }

    return hasValidSession;
  }

  static void stopSessionRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  static Future<bool> refreshSessionIfNeeded({bool force = false}) async {
    final inFlight = _refreshFuture;
    if (inFlight != null) {
      return inFlight;
    }

    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return hasValidSession;
    }

    if (!force && _tokenExpiresAt != null) {
      final refreshAt = _tokenExpiresAt!.subtract(_refreshLeadTime);
      if (DateTime.now().toUtc().isBefore(refreshAt)) {
        return true;
      }
    }

    _refreshFuture = _performTokenRefresh();
    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  static Future<bool> _performTokenRefresh() async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.tokenRefreshUrl),
            headers: _jsonHeaders,
            body: json.encode({'refresh_token': _refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      final body = response.body;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (isRefreshTokenInvalidResponse(response.statusCode, body)) {
          if (await _reauthenticateFromStoredCredentials()) {
            return true;
          }
          if (await _reauthenticateFromGoogleSilently()) {
            return true;
          }
          await invalidateSessionAfterHardFailure();
          return false;
        }

        if (response.statusCode >= 500) {
          return hasValidSession || hasStoredSession;
        }

        if (await _reauthenticateFromStoredCredentials()) {
          return true;
        }
        if (await _reauthenticateFromGoogleSilently()) {
          return true;
        }
        return hasValidSession || hasStoredSession;
      }

      final data = json.decode(body) as Map<String, dynamic>;
      final newAccessToken = data['access_token']?.toString();
      if (newAccessToken == null || newAccessToken.isEmpty) {
        if (await _reauthenticateFromStoredCredentials()) {
          return true;
        }
        if (await _reauthenticateFromGoogleSilently()) {
          return true;
        }
        return hasValidSession;
      }

      final newRefreshToken =
          data['refresh_token']?.toString() ?? _refreshToken;
      final expiresAt = _extractExpiresAt(data);

      await _persistSession(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresAt: expiresAt,
      );

      return true;
    } catch (error) {
      if (isRetryableNetworkError(error)) {
        return hasValidSession || hasStoredSession;
      }
      if (await _reauthenticateFromStoredCredentials()) {
        return true;
      }
      if (await _reauthenticateFromGoogleSilently()) {
        return true;
      }
      return hasValidSession;
    }
  }

  static Future<Map<String, dynamic>> _authorizedGet(
    Uri uri, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await _ensureSessionForProtectedApi();

    var headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
        'session_recovery_required': true,
      };
    }

    try {
      var response = await http.get(uri, headers: headers).timeout(timeout);
      var result = _handleResponse(response);

      if (isAuthFailureResponse(result)) {
        await _ensureSessionForProtectedApi();
        headers = _authorizedHeaders;
        if (headers != null) {
          response = await http.get(uri, headers: headers).timeout(timeout);
          result = _handleResponse(response);
        }
      }

      if (isHardSessionFailureResponse(result)) {
        result = {
          ...result,
          'session_recovery_required': !hasValidSession,
        };
      }

      return result;
    } catch (e) {
      if (isRetryableNetworkError(e)) {
        return {
          'success': false,
          'error': {'message': 'Network error: $e'},
          'retryable': true,
        };
      }
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> _authorizedPost(
    Uri uri, {
    required String body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await _ensureSessionForProtectedApi();

    var headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
        'session_recovery_required': true,
      };
    }

    try {
      var response =
          await http.post(uri, headers: headers, body: body).timeout(timeout);
      var result = _handleResponse(response);

      if (isAuthFailureResponse(result)) {
        await _ensureSessionForProtectedApi();
        headers = _authorizedHeaders;
        if (headers != null) {
          response =
              await http.post(uri, headers: headers, body: body).timeout(timeout);
          result = _handleResponse(response);
        }
      }

      if (isHardSessionFailureResponse(result)) {
        result = {
          ...result,
          'session_recovery_required': !hasValidSession,
        };
      }

      return result;
    } catch (e) {
      if (isRetryableNetworkError(e)) {
        return {
          'success': false,
          'error': {'message': 'Network error: $e'},
          'retryable': true,
        };
      }
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static String extractErrorMessage(
    Map<String, dynamic> response, {
    String fallback = 'Request failed. Please try again.',
  }) {
    final error = response['error'];
    if (error is String && error.isNotEmpty) return error;
    if (error is Map) {
      final message = error['message'] ?? error['error'];
      if (message is String && message.isNotEmpty) return message;
    }
    return fallback;
  }

  static Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'apikey': ApiConfig.supabaseAnonKey,
        'Accept-Language': AppLocaleService.instance.languageCode,
      };

  static Map<String, String> _authHeaders(String token) => {
        ..._jsonHeaders,
        'Authorization': 'Bearer $token',
      };

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.body.isEmpty) {
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      return {
        'success': ok,
        if (!ok) 'error': {'message': 'Empty response from server'},
      };
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data['success'] == false) {
        return {'success': false, 'error': data, 'data': data};
      }

      final inner = data['data'];
      if (data['success'] == true && inner is Map<String, dynamic>) {
        return {'success': true, 'data': inner};
      }

      return {'success': true, 'data': data};
    }

    return {'success': false, 'error': data};
  }

  static Map<String, dynamic> _handleSupabaseAuthResponse(http.Response response) {
    if (response.body.isEmpty) {
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      return {
        'success': ok,
        if (!ok) 'error': {'message': 'Empty response from server'},
      };
    }

    final decoded = json.decode(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is Map<String, dynamic> &&
        decoded['access_token'] is String) {
      return {'success': true, 'data': decoded};
    }

    if (decoded is Map<String, dynamic>) {
      final message = decoded['msg'] ??
          decoded['error_description'] ??
          decoded['message'] ??
          decoded['error'];
      return {
        'success': false,
        'error': {
          'message': message is String && message.isNotEmpty
              ? message
              : 'Google sign-in failed.',
        },
      };
    }

    return {
      'success': false,
      'error': {'message': 'Google sign-in failed.'},
    };
  }

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile', 'openid'],
    clientId: !kIsWeb && Platform.isIOS ? ApiConfig.googleIosClientId : null,
    serverClientId: ApiConfig.googleWebClientId,
  );

  static Future<void> _clearGoogleSignInSession() async {
    try {
      await _googleSignIn.signOut().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Non-blocking — sign-in can still proceed.
    }
  }

  static Future<bool> _reauthenticateFromGoogleSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return false;

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) return false;

      final result = await _exchangeGoogleIdTokenForSession(
        idToken: idToken,
        googleAccessToken: googleAuth.accessToken,
      );
      if (result['success'] != true) return false;

      final data = result['data'];
      if (data is Map<String, dynamic>) {
        await _persistSessionFromAuthData(data);
      }
      return hasValidSession;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> _exchangeGoogleIdTokenForSession({
    required String idToken,
    String? googleAccessToken,
  }) async {
    final body = <String, dynamic>{
      'provider': 'google',
      'id_token': idToken,
    };
    if (googleAccessToken != null && googleAccessToken.isNotEmpty) {
      body['access_token'] = googleAccessToken;
    }

    final response = await http
        .post(
          Uri.parse(ApiConfig.supabaseGoogleIdTokenUrl),
          headers: _jsonHeaders,
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 30));

    return _handleSupabaseAuthResponse(response);
  }

  static Future<Map<String, dynamic>> driverGoogleSignIn({
    VoidCallback? onAccountSelected,
    bool completeRegistration = true,
  }) async {
    try {
      await SplashVideoModel.suppressIntro();
      await _clearGoogleSignInSession();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        return {
          'success': false,
          'cancelled': true,
          'error': {'message': 'Google sign-in was cancelled.'},
        };
      }

      await SplashVideoModel.suppressIntro();
      onAccountSelected?.call();

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return {
          'success': false,
          'error': {
            'message':
                'Could not get a Google ID token. Check your OAuth client setup.',
          },
        };
      }

      final googleAccessToken = googleAuth.accessToken;
      final result = await _exchangeGoogleIdTokenForSession(
        idToken: idToken,
        googleAccessToken: googleAccessToken,
      );
      if (result['success'] == true) {
        final data = result['data'];
        if (data is Map<String, dynamic>) {
          await _persistSessionFromAuthData(data);
        }

        if (!completeRegistration) {
          var prefill = buildOAuthSignupPrefill(
            authData: data is Map<String, dynamic> ? data : null,
            displayName: account.displayName,
            email: account.email,
            idToken: idToken,
          );
          prefill = await enrichOAuthSignupPrefill(prefill);
          return {
            'success': true,
            'data': data,
            'prefill': prefill.toJson(),
          };
        }

        final oauthResult = await driverOAuthSignup();
        if (oauthResult['success'] != true) {
          await invalidateStoredSession();
          return oauthResult;
        }

        await markOnboardingCompleted();

        final mergedData = <String, dynamic>{};
        if (data is Map<String, dynamic>) {
          mergedData.addAll(data);
        }
        final oauthData = oauthResult['data'];
        if (oauthData is Map<String, dynamic>) {
          mergedData.addAll(unwrapAuthPayload(oauthData));
        }

        await _persistSessionFromAuthData(mergedData);
        return {'success': true, 'data': mergedData};
      }
      return result;
    } on PlatformException catch (e) {
      return {
        'success': false,
        'error': {
          'message': e.message ?? 'Google sign-in failed.',
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> driverAppleSignIn({
    bool completeRegistration = true,
  }) async {
    try {
      await SplashVideoModel.suppressIntro();
      final credentials = await AppleSignInService.getCredentials();

      final response = await http
          .post(
            Uri.parse(ApiConfig.supabaseGoogleIdTokenUrl),
            headers: _jsonHeaders,
            body: json.encode({
              'provider': 'apple',
              'id_token': credentials.idToken,
              'nonce': credentials.rawNonce,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final result = _handleSupabaseAuthResponse(response);
      if (result['success'] == true) {
        final data = result['data'];
        if (data is Map<String, dynamic>) {
          await _persistSessionFromAuthData(data);
        }

        if (!completeRegistration) {
          final appleFullName = _fullNameFromNameParts(
            givenName: credentials.givenName,
            familyName: credentials.familyName,
          );
          if (appleFullName != null) {
            await syncOAuthAuthUserMetadata(
              fullName: appleFullName,
              givenName: credentials.givenName,
              familyName: credentials.familyName,
            );
          }

          var prefill = buildOAuthSignupPrefill(
            authData: data is Map<String, dynamic> ? data : null,
            givenName: credentials.givenName,
            familyName: credentials.familyName,
            email: credentials.email,
            idToken: credentials.idToken,
          );
          prefill = await enrichOAuthSignupPrefill(prefill);
          return {
            'success': true,
            'data': data,
            'prefill': prefill.toJson(),
          };
        }

        final oauthResult = await driverOAuthSignup();
        if (oauthResult['success'] != true) {
          await invalidateStoredSession();
          return oauthResult;
        }

        await markOnboardingCompleted();

        final mergedData = <String, dynamic>{};
        if (data is Map<String, dynamic>) {
          mergedData.addAll(data);
        }
        final oauthData = oauthResult['data'];
        if (oauthData is Map<String, dynamic>) {
          mergedData.addAll(unwrapAuthPayload(oauthData));
        }

        await _persistSessionFromAuthData(mergedData);
        return {'success': true, 'data': mergedData};
      }
      return result;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return {
          'success': false,
          'cancelled': true,
          'error': {'message': 'Apple sign-in was cancelled.'},
        };
      }
      return {
        'success': false,
        'error': {
          'message': e.message,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> driverOAuthSignup({
    String? phone,
    String? referralCode,
    String? partnerCode,
    String countryCode = ApiConfig.defaultCountryCode,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final body = <String, dynamic>{};
    final trimmedPhone = phone?.trim();
    if (trimmedPhone != null && trimmedPhone.isNotEmpty) {
      body['phone'] = trimmedPhone;
      body['country_code'] = countryCode;
    }
    final referral = referralCode?.trim();
    if (referral != null && referral.isNotEmpty) {
      body['referral_code'] = referral;
    }
    final partner = partnerCode?.trim();
    if (partner != null && partner.isNotEmpty) {
      body['partner_code'] = partner;
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.driverOAuthSignupUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Map<String, dynamic>? decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final parsed = json.decode(decoded);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {
      // Ignore malformed token payloads.
    }
    return null;
  }

  static DateTime? _accessTokenExpiryFromJwt() {
    final token = _accessToken;
    if (token == null || token.isEmpty) return null;
    final payload = decodeJwtPayload(token);
    final exp = payload?['exp'];
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
    }
    return null;
  }

  static String? _fullNameFromNameParts({
    String? name,
    String? givenName,
    String? familyName,
  }) {
    final direct = _readNullableString(name);
    if (direct != null) return direct;

    final given = _readNullableString(givenName);
    final family = _readNullableString(familyName);
    if (given == null && family == null) return null;

    final combined = [given, family].whereType<String>().join(' ').trim();
    return combined.isEmpty ? null : combined;
  }

  static String? _fullNameFromJwtClaims(Map<String, dynamic> claims) {
    return _fullNameFromNameParts(
      name: claims['name']?.toString(),
      givenName: claims['given_name']?.toString(),
      familyName: claims['family_name']?.toString(),
    );
  }

  static String? _nameFallbackFromEmail(String? email) {
    final resolved = _readNullableString(email);
    if (resolved == null) return null;

    final localPart = resolved.split('@').first.trim();
    if (localPart.isEmpty) return null;

    final normalized = localPart
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? null : normalized;
  }

  static OAuthSignupPrefill buildOAuthSignupPrefill({
    Map<String, dynamic>? authData,
    String? displayName,
    String? givenName,
    String? familyName,
    String? email,
    String? idToken,
  }) {
    String? fullName = _fullNameFromNameParts(
      name: displayName,
      givenName: givenName,
      familyName: familyName,
    );
    String? resolvedEmail = _readNullableString(email);
    String? phone;

    final claims = idToken != null ? decodeJwtPayload(idToken) : null;
    if (claims != null) {
      fullName ??= _fullNameFromJwtClaims(claims);
      resolvedEmail ??= _readNullableString(claims['email']?.toString());
    }

    final user = authData?['user'];
    if (user is Map<String, dynamic>) {
      resolvedEmail ??= _readNullableString(user['email']);
      final metadata = user['user_metadata'];
      if (metadata is Map<String, dynamic>) {
        fullName ??= _fullNameFromNameParts(
          name: metadata['name']?.toString(),
          givenName: metadata['given_name']?.toString(),
          familyName: metadata['family_name']?.toString(),
        );
        fullName ??= _readNullableString(metadata['full_name']);
        resolvedEmail ??= _readNullableString(metadata['email']);
        phone = extractProfilePhone(metadata);
      }
    }

    fullName ??= _nameFallbackFromEmail(resolvedEmail);

    return OAuthSignupPrefill(
      fullName: fullName,
      email: resolvedEmail,
      phone: phone,
    );
  }

  static Future<OAuthSignupPrefill> enrichOAuthSignupPrefill(
    OAuthSignupPrefill prefill,
  ) async {
    var fullName = prefill.fullName;
    var email = prefill.email;
    var phone = prefill.phone;

    if ((fullName == null || fullName.isEmpty) && isLoggedIn) {
      final profile = await getUserProfile();
      if (profile['success'] == true) {
        final profileData = profile['data'];
        if (profileData is Map<String, dynamic>) {
          fullName ??= extractProfileFullName(profileData);
          email ??= extractProfileEmail(profileData);
          phone ??= extractProfilePhone(profileData);
        }
      }
    }

    fullName ??= _nameFallbackFromEmail(email);

    return OAuthSignupPrefill(
      fullName: fullName,
      email: email,
      phone: phone,
    );
  }

  static Future<void> syncOAuthAuthUserMetadata({
    String? fullName,
    String? givenName,
    String? familyName,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) return;

    final metadata = <String, dynamic>{};
    final trimmedName = fullName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      metadata['full_name'] = trimmedName;
      metadata['name'] = trimmedName;
    }
    final trimmedGiven = givenName?.trim();
    if (trimmedGiven != null && trimmedGiven.isNotEmpty) {
      metadata['given_name'] = trimmedGiven;
    }
    final trimmedFamily = familyName?.trim();
    if (trimmedFamily != null && trimmedFamily.isNotEmpty) {
      metadata['family_name'] = trimmedFamily;
    }
    if (metadata.isEmpty) return;

    try {
      await http
          .put(
            Uri.parse(ApiConfig.supabaseAuthUserUrl),
            headers: headers,
            body: json.encode({'data': metadata}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Non-blocking — signup can still continue with form prefill.
    }
  }

  static Future<Map<String, dynamic>> patchOAuthSignupProfile({
    String? fullName,
    String? email,
    String? phone,
    String countryCode = ApiConfig.defaultCountryCode,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final body = <String, dynamic>{};
    final trimmedName = fullName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      body['full_name'] = trimmedName;
    }
    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      body['email'] = trimmedEmail;
    }
    final trimmedPhone = phone?.trim();
    if (trimmedPhone != null && trimmedPhone.isNotEmpty) {
      body['phone'] = trimmedPhone;
      body['country_code'] = countryCode;
    }

    if (body.isEmpty) {
      return {'success': true, 'data': <String, dynamic>{}};
    }

    try {
      final response = await http
          .put(
            Uri.parse(ApiConfig.editProfileUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> completeOAuthDriverSignup({
    required String fullName,
    required String email,
    required String phoneNumber,
    String? referralCode,
    String? partnerCode,
    String countryCode = ApiConfig.defaultCountryCode,
  }) async {
    final trimmedName = fullName.trim();
    final trimmedEmail = email.trim();
    final trimmedPhone = phoneNumber.trim();

    if (trimmedName.isEmpty ||
        trimmedEmail.isEmpty ||
        trimmedPhone.isEmpty) {
      return {
        'success': false,
        'error': {'message': 'Please fill in all required fields.'},
      };
    }

    final patchResult = await patchOAuthSignupProfile(
      fullName: trimmedName,
      email: trimmedEmail,
      phone: trimmedPhone,
      countryCode: countryCode,
    );
    if (patchResult['success'] != true) {
      return patchResult;
    }

    final normalizedPhone = normalizeDriverPhone(
      phone: trimmedPhone,
      countryCode: countryCode,
    );

    final oauthResult = await driverOAuthSignup(
      phone: normalizedPhone,
      referralCode: referralCode,
      partnerCode: partnerCode,
      countryCode: countryCode,
    );
    if (oauthResult['success'] != true) {
      return oauthResult;
    }

    await markOnboardingCompleted();
    await savePendingVerificationContext(
      phone: trimmedPhone,
      email: trimmedEmail,
      countryCode: countryCode,
      firebasePhoneE164: extractFirebasePhoneE164(oauthResult),
    );
    await DriverStatusService.recordSignupStep(
      accessRoute: DriverAccessRoute.phoneVerification,
      status: const DriverStatus(
        isVerified: false,
        isApproved: false,
        canAcceptRides: false,
        phoneVerified: false,
        onboarding: DriverOnboarding(
          documents: DriverDocumentsOnboarding(complete: false),
          vehicleDetails: DriverVehicleDetailsOnboarding(complete: false),
          onboardingComplete: false,
          nextStep: 'upload_documents',
        ),
      ),
      statusResponse: oauthResult,
    );

    final mergedData = <String, dynamic>{};
    final oauthData = oauthResult['data'];
    if (oauthData is Map<String, dynamic>) {
      mergedData.addAll(unwrapAuthPayload(oauthData));
    }

    return {'success': true, 'data': mergedData};
  }

  static Future<Map<String, dynamic>> driverLogin({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.driverLoginUrl),
            headers: _jsonHeaders,
            body: json.encode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final result = _handleResponse(response);
      if (result['success'] == true) {
        final data = result['data'];
        if (data is Map<String, dynamic>) {
          await _persistSessionFromAuthData(data);
        }
        await syncReferralFromAnyResponse(result);
        await _saveReferralRepollCredentials(
          email: email,
          password: password,
        );
        await markOnboardingCompleted();
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> getDriverOnboardingStatus() async {
    await _ensureSessionForProtectedApi();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.driverOnboardingStatusUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  /// Reads uploaded document types from onboarding-status or profile payloads.
  static List<String> extractUploadedDocumentTypes(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return const [];

    final uploaded = <String>{};

    final documentsMap = _findDocumentsMap(response);
    if (documentsMap != null) {
      _applyDocumentsMap(documentsMap, uploaded);
    }

    final status = DriverStatusService.extractFromOnboarding(response) ??
        DriverStatusService.extractFromProfile(response);
    _addUploadedFromDocumentsOnboarding(status?.onboarding?.documents, uploaded);

    uploaded.addAll(_collectUploadedDocumentTypes(response['data']));

    final profile = extractUserProfile(response);
    if (profile != null) {
      uploaded.addAll(_collectUploadedDocumentTypes(profile));
      if (extractAvatarUrl(profile) != null) {
        uploaded.add(DriverDocumentType.profilePicture);
      }
    }

    return uploaded
        .where(DriverDocumentType.all.contains)
        .toList()
      ..sort();
  }

  static void _applyDocumentsMap(
    Map<dynamic, dynamic> documentsMap,
    Set<String> uploaded,
  ) {
    _collectFromDocumentTypeKeyedMap(documentsMap, uploaded);

    for (final key in const [
      'uploaded',
      'uploaded_types',
      'uploaded_documents',
      'submitted',
      'completed_documents',
    ]) {
      uploaded.addAll(_documentTypesFromDynamicList(documentsMap[key]));
    }

    _addUploadedFromDocumentsOnboarding(
      DriverDocumentsOnboarding.fromMap(documentsMap),
      uploaded,
    );
  }

  static List<String> _documentTypesFromDynamicList(dynamic value) {
    if (value is! List) return const [];

    final types = <String>{};
    for (final item in value) {
      if (item is String && item.trim().isNotEmpty) {
        types.add(item.trim());
        continue;
      }
      if (item is Map) {
        final type = _readDocumentType(item);
        if (type != null) {
          types.add(type);
        }
      }
    }
    return types.toList();
  }

  /// Fetches uploaded document types from onboarding-status and user profile.
  static Future<List<String>> resolveUploadedDocumentTypes() async {
    await _ensureSessionForProtectedApi();

    final uploaded = <String>{};

    final onboardingResponse = await getDriverOnboardingStatus();
    uploaded.addAll(extractUploadedDocumentTypes(onboardingResponse));

    final profileResponse = await getUserProfile();
    uploaded.addAll(extractUploadedDocumentTypes(profileResponse));

    return uploaded.toList()..sort();
  }

  static Future<void> _ensureSessionForProtectedApi() async {
    await loadStoredSessionFromDisk();
    await _tryRecoverExpiredSession();
  }

  static bool isDocumentAlreadyUploadedResponse(Map<String, dynamic> response) {
    if (response['success'] == true) return false;

    final message = extractErrorMessage(response).toLowerCase();
    return (message.contains('already') && message.contains('upload')) ||
        message.contains('already uploaded') ||
        message.contains('already been uploaded') ||
        message.contains('document exists');
  }

  static void _addUploadedFromDocumentsOnboarding(
    DriverDocumentsOnboarding? documents,
    Set<String> uploaded,
  ) {
    if (documents == null) return;

    uploaded.addAll(documents.uploaded);

    final missing = documents.missing.toSet();
    if (documents.required.isNotEmpty) {
      uploaded.addAll(
        documents.required.where((type) => !missing.contains(type)),
      );
      return;
    }

    if (missing.isNotEmpty) {
      uploaded.addAll(
        DriverDocumentType.all.where((type) => !missing.contains(type)),
      );
    }
  }

  static List<String> _collectUploadedDocumentTypes(dynamic node) {
    final uploaded = <String>{};
    _walkForUploadedDocumentTypes(node, uploaded, depth: 0);
    return uploaded.toList();
  }

  static void _walkForUploadedDocumentTypes(
    dynamic node,
    Set<String> uploaded, {
    required int depth,
  }) {
    if (node == null || depth > 8) return;

    if (node is List) {
      for (final item in node) {
        _walkForUploadedDocumentTypes(item, uploaded, depth: depth + 1);
      }
      return;
    }

    if (node is! Map) return;

    _collectFromDocumentTypeKeyedMap(node, uploaded);

    for (final key in const [
      'uploaded',
      'uploaded_types',
      'uploaded_documents',
      'completed_documents',
      'submitted',
    ]) {
      uploaded.addAll(_documentTypesFromDynamicList(node[key]));
    }

    for (final entry in node.entries) {
      final key = entry.key.toString().toLowerCase();
      final value = entry.value;

      if (value is Map &&
          (key == 'documents' ||
              key.endsWith('_documents') ||
              key.contains('document'))) {
        _applyDocumentsMap(value, uploaded);
      }

      if (value is Map) {
        final type = _readDocumentType(value);
        if (type != null &&
            (_isUploadedDocumentRecord(value) ||
                _hasDocumentFileReference(value))) {
          uploaded.add(type);
        }
      }

      _walkForUploadedDocumentTypes(value, uploaded, depth: depth + 1);
    }
  }

  static String? _readDocumentType(Map<dynamic, dynamic> map) {
    for (final key in const [
      'document_type',
      'documentType',
      'type',
      'doc_type',
    ]) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static bool _isUploadedDocumentRecord(Map<dynamic, dynamic> map) {
    for (final key in const ['uploaded', 'is_uploaded', 'complete', 'completed']) {
      if (map[key] == true) return true;
    }

    final status = map['status']?.toString().toLowerCase();
    if (status == null || status.isEmpty) return false;
    return status.contains('upload') ||
        status.contains('complete') ||
        status.contains('approved') ||
        status.contains('verified');
  }

  static void _collectFromDocumentTypeKeyedMap(
    Map<dynamic, dynamic> map,
    Set<String> uploaded,
  ) {
    for (final entry in map.entries) {
      final type = entry.key.toString().trim();
      if (!DriverDocumentType.all.contains(type)) continue;

      final value = entry.value;
      if (value == null || value == false) continue;
      if (value == true) {
        uploaded.add(type);
        continue;
      }
      if (value is String && value.trim().isNotEmpty && value != 'null') {
        uploaded.add(type);
        continue;
      }
      if (value is Map &&
          (_isUploadedDocumentRecord(value) ||
              _hasDocumentFileReference(value) ||
              _hasTruthyDocumentStatus(value))) {
        uploaded.add(type);
      }
    }
  }

  static bool _hasTruthyDocumentStatus(Map<dynamic, dynamic> map) {
    final status = map['status']?.toString().toLowerCase();
    if (status == null || status.isEmpty) return false;
    if (status.contains('missing') ||
        status.contains('pending') ||
        status.contains('rejected') ||
        status.contains('required')) {
      return false;
    }
    return true;
  }

  static bool _hasDocumentFileReference(Map<dynamic, dynamic> map) {
    for (final key in const [
      'url',
      'file_url',
      'document_url',
      'path',
      'file_path',
      'storage_path',
    ]) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return true;
    }
    return false;
  }

  static Map<dynamic, dynamic>? _findDocumentsMap(
    Map<String, dynamic> response,
  ) {
    final data = response['data'];
    if (data is! Map) return null;

    final payload = data['data'] is Map ? data['data'] as Map : data;
    final onboarding = payload['onboarding'];
    if (onboarding is Map && onboarding['documents'] is Map) {
      return onboarding['documents'] as Map;
    }

    final driverStatus = payload['driver_status'];
    if (driverStatus is Map) {
      final nestedOnboarding = driverStatus['onboarding'];
      if (nestedOnboarding is Map && nestedOnboarding['documents'] is Map) {
        return nestedOnboarding['documents'] as Map;
      }
    }

    if (payload['documents'] is Map) {
      return payload['documents'] as Map;
    }

    return null;
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.forgotPasswordUrl),
            headers: _jsonHeaders,
            body: json.encode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static String extractSuccessMessage(
    Map<String, dynamic> response, {
    String fallback = 'Request completed successfully.',
  }) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final payload = unwrapAuthPayload(data);
      final message = payload['message'];
      if (message is String && message.isNotEmpty) return message;
    }

    final message = response['message'];
    if (message is String && message.isNotEmpty) return message;

    return fallback;
  }

  /// Reads `phone_verification.firebase_phone_e164` from signup/auth responses.
  static String? extractFirebasePhoneE164(Map<String, dynamic> response) {
    final candidates = <Map<String, dynamic>>[];
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      candidates.add(data);
      candidates.add(unwrapAuthPayload(data));
    }
    candidates.add(response);

    for (final map in candidates) {
      final phoneVerification = map['phone_verification'];
      if (phoneVerification is! Map) continue;
      final e164 = _readNullableString(phoneVerification['firebase_phone_e164']);
      if (e164 == null || e164.isEmpty) continue;
      if (e164.startsWith('+')) return e164;
      final digits = e164.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) return '+$digits';
    }
    return null;
  }

  static Future<Map<String, dynamic>> driverSignup({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
    String? referralCode,
    String? partnerCode,
    String countryCode = ApiConfig.defaultCountryCode,
  }) async {
    try {
      final body = <String, dynamic>{
        'full_name': fullName.trim(),
        'email': email.trim(),
        'country_code': countryCode,
        'phone_number': phoneNumber.trim(),
        'password': password,
        'confirm_password': confirmPassword,
      };

      final referral = referralCode?.trim();
      if (referral != null && referral.isNotEmpty) {
        body['referral_code'] = referral;
      }
      final partner = partnerCode?.trim();
      if (partner != null && partner.isNotEmpty) {
        body['partner_code'] = partner;
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.driverSignupUrl),
            headers: _jsonHeaders,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      final result = _handleResponse(response);
      if (result['success'] == true) {
        final firebasePhoneE164 = extractFirebasePhoneE164(result);
        await markOnboardingCompleted();
        await savePendingVerificationContext(
          phone: phoneNumber,
          email: email,
          password: password,
          countryCode: countryCode,
          firebasePhoneE164: firebasePhoneE164,
        );
        await DriverStatusService.recordSignupStep(
          accessRoute: DriverAccessRoute.phoneVerification,
          status: const DriverStatus(
            isVerified: false,
            isApproved: false,
            canAcceptRides: false,
            phoneVerified: false,
            onboarding: DriverOnboarding(
              documents: DriverDocumentsOnboarding(complete: false),
              vehicleDetails: DriverVehicleDetailsOnboarding(complete: false),
              onboardingComplete: false,
              nextStep: 'upload_documents',
            ),
          ),
          statusResponse: result,
        );
        final sessionResult = await signInWithPassword(
          email: email,
          password: password,
        );
        if (sessionResult['success'] == true) {
          await saveSignupBootstrapCredentials(
            email: email,
            password: password,
          );
        }
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> confirmPhoneVerification({
    required String firebaseIdToken,
    required String phoneNumber,
    String? email,
  }) async {
    await refreshSessionIfNeeded();

    final normalizedPhone = normalizeMobileForDeposit(phone: phoneNumber);
    if (normalizedPhone.isEmpty) {
      return {
        'success': false,
        'error': {'message': 'Invalid phone number.'},
      };
    }

    final headers = isLoggedIn && _accessToken != null && _accessToken!.isNotEmpty
        ? _authHeaders(_accessToken!)
        : _jsonHeaders;

    final body = <String, dynamic>{
      'firebase_id_token': firebaseIdToken,
      'phone_number': normalizedPhone,
    };
    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      body['email'] = trimmedEmail;
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.phoneVerificationConfirmUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      final result = _handleResponse(response);
      if (result['success'] == true) {
        final data = result['data'];
        if (data is Map<String, dynamic>) {
          await _persistSessionFromAuthData(data);
        }
        await DriverStatusService.clearStored();
        await markSignupResumeAfterPhoneVerification();
        await clearPendingPhoneContext();
        if (!isLoggedIn) {
          await ensureAuthenticatedSession();
        }
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Map<String, String>? get _authorizedHeaders {
    final token = _accessToken;
    if (token == null || token.isEmpty) return null;
    return _authHeaders(token);
  }

  static bool? extractIsOnlineFromResponse(Map<String, dynamic> response) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;
    final payload = unwrapAuthPayload(data);
    final value = payload['is_online'];
    return value is bool ? value : null;
  }

  static Future<Map<String, dynamic>> driverSetStatus({
    required bool isOnline,
    double? latitude,
    double? longitude,
  }) async {
    return _authorizedPost(
      Uri.parse(ApiConfig.driverSetStatusUrl),
      body: json.encode({
        'is_online': isOnline,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      }),
    );
  }

  static Future<Map<String, dynamic>> updateDriverLocation({
    required double latitude,
    required double longitude,
    double? heading,
    required bool isAvailable,
    String? rideId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.updateDriverLocationUrl),
            headers: headers,
            body: json.encode({
              'latitude': latitude,
              'longitude': longitude,
              if (heading != null) 'heading': heading,
              'is_available': isAvailable,
              if (rideId != null && rideId.isNotEmpty) 'ride_id': rideId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Map<String, dynamic>? extractTodayStats(Map<String, dynamic> response) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final directToday = data['today'];
    if (directToday is Map<String, dynamic>) return directToday;

    final nested = data['data'];
    if (nested is Map<String, dynamic> && nested['today'] is Map<String, dynamic>) {
      return nested['today'] as Map<String, dynamic>;
    }

    return null;
  }

  static DriverWalletBalance? extractWalletBalance(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final candidates = <Map<String, dynamic>>[];
    void addCandidate(dynamic value) {
      if (value is Map<String, dynamic>) {
        candidates.add(value);
      } else if (value is Map) {
        candidates.add(Map<String, dynamic>.from(value));
      }
    }

    final payload = unwrapAuthPayload(data);
    addCandidate(payload);
    addCandidate(payload['wallets']);
    addCandidate(payload['wallet']);
    addCandidate(payload['wallet_balance']);
    addCandidate(data['wallets']);
    addCandidate(data['wallet_balance']);

    for (final candidate in candidates) {
      final wallet = _parseWalletPayload(candidate);
      if (wallet != null) return wallet;
    }

    return null;
  }

  static DriverWalletBalance? _parseWalletPayload(Map<String, dynamic> json) {
    if (_hasWalletBalanceFields(json) || _looksLikeLegacyWalletPayload(json)) {
      return DriverWalletBalance.fromJson(json);
    }
    return null;
  }

  static bool _looksLikeLegacyWalletPayload(Map<String, dynamic> json) {
    return json.containsKey('balance') ||
        json.containsKey('available_balance') ||
        json.containsKey('raw_balance') ||
        json.containsKey('verified_balance') ||
        json.containsKey('spendable_balance');
  }

  /// Returns and clears any wallet prefetched before navigating to home.
  static DriverWalletBalance? takePrefetchedWalletBalance() {
    final wallet = _prefetchedWalletBalance;
    _prefetchedWalletBalance = null;
    return wallet;
  }

  /// Loads wallet data before home mounts so first-time login shows balances immediately.
  static Future<DriverWalletBalance?> prefetchWalletBalanceForHome({
    int maxAttempts = 6,
  }) async {
    _prefetchedWalletBalance = null;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await maintainSession();
        await Future<void>.delayed(
          Duration(milliseconds: 500 + (attempt * attempt * 400)),
        );
      } else {
        await refreshSessionIfNeeded(force: true);
      }

      final response = await getWalletBalance();
      if (isUnauthorizedResponse(response)) {
        await maintainSession();
        continue;
      }

      final wallet = extractWalletBalance(response);
      if (wallet != null) {
        _prefetchedWalletBalance = wallet;
        return wallet;
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>> getWalletBalance({
    bool includeVerified = true,
    bool includeToday = true,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final uri = Uri.parse(ApiConfig.getWalletBalanceUrl).replace(
      queryParameters: {
        'include_verified': includeVerified ? '1' : '0',
        'include_today': includeToday ? '1' : '0',
      },
    );

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static DriverCompletedTripsResult? extractCompletedTrips(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    final tripsRaw = payload['trips'];
    final trips = tripsRaw is List
        ? tripsRaw
            .whereType<Map>()
            .map(
              (trip) => DriverCompletedTrip.fromJson(
                Map<String, dynamic>.from(trip),
              ),
            )
            .where((trip) => trip.id.isNotEmpty)
            .toList()
        : <DriverCompletedTrip>[];

    final pagination = payload['pagination'];
    final limit = pagination is Map<String, dynamic>
        ? _readTripPaginationInt(pagination['limit'], fallback: trips.length)
        : trips.length;
    final offset = pagination is Map<String, dynamic>
        ? _readTripPaginationInt(pagination['offset'])
        : 0;
    final hasMore = pagination is Map<String, dynamic>
        ? pagination['has_more'] == true
        : false;
    final totalCount = _readTripPaginationInt(
      payload['total_count'],
      fallback: trips.length,
    );

    return DriverCompletedTripsResult(
      trips: trips,
      totalCount: totalCount,
      limit: limit,
      offset: offset,
      hasMore: hasMore,
    );
  }

  static int _readTripPaginationInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Future<Map<String, dynamic>> getDriverCompletedTrips({
    int limit = 4,
    int offset = 0,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final uri = Uri.parse(ApiConfig.driverCompletedTripsUrl).replace(
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> getDriverCompletedTripDetails({
    required String rideId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final uri = Uri.parse(ApiConfig.driverCompletedTripDetailsUrl).replace(
      queryParameters: {'ride_id': rideId},
    );

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static DriverRideDetails? extractCompletedTripDetails(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;

    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    final trip = payload['trip'];
    if (trip is! Map) return null;

    final details = DriverRideDetails.fromCompletedTripPayload(
      Map<String, dynamic>.from(trip),
    );
    if (details.id.isEmpty) return null;
    return details;
  }

  static Future<Map<String, dynamic>> getDriverTodayStats() async {
    return _authorizedGet(Uri.parse(ApiConfig.driverTodayStatsUrl));
  }

  static Map<String, dynamic>? _findIncentiveProgressRoot(
    Map<String, dynamic> root, {
    int maxDepth = 4,
  }) {
    if (_isIncentivePayload(root)) return root;
    if (maxDepth <= 0) return null;

    for (final value in root.values) {
      if (value is! Map<String, dynamic>) continue;
      final found = _findIncentiveProgressRoot(
        value,
        maxDepth: maxDepth - 1,
      );
      if (found != null) return found;
    }

    return null;
  }

  static bool _isIncentivePayload(Map<String, dynamic> map) {
    return map['progress'] is Map<String, dynamic> ||
        map['config'] is Map<String, dynamic> ||
        map['thresholds'] is Map<String, dynamic>;
  }

  static SignupPerformanceBonus? extractSignupPerformanceBonus(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = _findIncentiveProgressRoot(data);
    if (payload == null) return null;

    return SignupPerformanceBonus.fromIncentiveProgressData(payload);
  }

  static DriverReferralProgress? extractDriverReferralProgress(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    return DriverReferralProgress.fromReferralProgressData(data);
  }

  static Future<Map<String, dynamic>> getDriverReferralProgress() async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.driverReferralProgressUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      final result = _handleResponse(response);
      await syncReferralFromAnyResponse(result);
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> getDriverIncentiveProgress() async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.driverIncentiveProgressUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      final result = _handleResponse(response);
      await syncReferralFromAnyResponse(result);
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Map<String, dynamic>? extractUserProfile(Map<String, dynamic> response) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    if (payload['profile'] is Map<String, dynamic>) {
      return payload['profile'] as Map<String, dynamic>;
    }

    if (data['profile'] is Map<String, dynamic>) {
      return data['profile'] as Map<String, dynamic>;
    }

    final nested = data['data'];
    if (nested is Map<String, dynamic> &&
        nested['profile'] is Map<String, dynamic>) {
      return nested['profile'] as Map<String, dynamic>;
    }

    if (payload['full_name'] != null ||
        payload['personal_details'] != null ||
        payload['avatar_url'] != null) {
      return payload;
    }

    return null;
  }

  static String? _readNullableUrl(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'null') return null;
    return trimmed;
  }

  static String? _readNullableString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? extractProfileFullName(Map<String, dynamic> profile) {
    final personal = profile['personal_details'];
    if (personal is Map<String, dynamic>) {
      final name = _readNullableString(personal['full_name']);
      if (name != null) return name;
    }
    return _readNullableString(profile['full_name']);
  }

  static Map<String, dynamic> unwrapProfilePayload(Map<String, dynamic> payload) {
    if (payload['profile'] is Map<String, dynamic>) {
      return payload['profile'] as Map<String, dynamic>;
    }
    return payload;
  }

  static String? extractProfileEmail(Map<String, dynamic> profile) {
    final resolved = unwrapProfilePayload(profile);
    final personal = resolved['personal_details'];
    if (personal is Map<String, dynamic>) {
      final email = _readNullableString(personal['email']);
      if (email != null) return email;
    }
    return _readNullableString(resolved['email']);
  }

  static String? extractProfilePhone(Map<String, dynamic> profile) {
    final resolved = unwrapProfilePayload(profile);
    final countryCode =
        extractProfileCountryCode(resolved) ?? ApiConfig.defaultCountryCode;
    final personal = resolved['personal_details'];
    final sources = <Map<String, dynamic>>[
      if (personal is Map<String, dynamic>) personal,
      resolved,
    ];

    for (final source in sources) {
      for (final key in ['phone', 'phone_number', 'mobile']) {
        final value = _readNullableString(source[key]);
        if (value == null) continue;
        final normalized = normalizeDriverPhone(
          phone: value,
          countryCode: countryCode,
        );
        if (normalized.length >= 11) return normalized;
      }
    }
    return null;
  }

  static String? extractProfileCountryCode(Map<String, dynamic> profile) {
    final resolved = unwrapProfilePayload(profile);
    final code = _readNullableString(resolved['country_code']);
    if (code != null) return code;
    final personal = resolved['personal_details'];
    if (personal is Map<String, dynamic>) {
      return _readNullableString(personal['country_code']);
    }
    return null;
  }

  /// Normalizes a Qatar driver phone to digits with country code (e.g. 97455123456).
  static String normalizeDriverPhone({
    required String phone,
    String countryCode = ApiConfig.defaultCountryCode,
  }) {
    const qatarCode = '974';
    final codeDigits =
        countryCode.replaceAll(RegExp(r'\D'), '').isEmpty
            ? qatarCode
            : countryCode.replaceAll(RegExp(r'\D'), '');
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits == codeDigits || digits == qatarCode) return '';

    if (digits.startsWith(codeDigits) && digits.length > codeDigits.length) {
      final local = digits.substring(codeDigits.length);
      if (local.length == 8) return '$codeDigits$local';
      if (digits.length >= codeDigits.length + 8) {
        return digits.substring(0, codeDigits.length + 8);
      }
    }

    if (digits.length == 8) return '$codeDigits$digits';

    if (digits.startsWith(qatarCode) && digits.length >= 11) {
      return digits.substring(0, 11);
    }

    final combinedDigits =
        '$codeDigits$digits'.replaceAll(RegExp(r'\D'), '');
    if (combinedDigits.isEmpty ||
        combinedDigits == codeDigits ||
        combinedDigits == qatarCode) {
      return '';
    }
    if (combinedDigits.startsWith(qatarCode) && combinedDigits.length >= 11) {
      return combinedDigits.substring(0, 11);
    }
    if (combinedDigits.length == 8) return '$qatarCode$combinedDigits';
    return '';
  }

  static String normalizeMobileForDeposit({
    String? countryCode,
    String? phone,
  }) {
    final normalized = normalizeDriverPhone(
      phone: phone ?? '',
      countryCode: countryCode ?? ApiConfig.defaultCountryCode,
    );
    if (normalized.isNotEmpty) return normalized;

    final combined =
        '${countryCode ?? ''}${phone ?? ''}'.replaceAll(RegExp(r'\D'), '');
    if (combined.isEmpty) return '';
    if (combined == '974') return '';
    if (combined.startsWith('974') && combined.length >= 11) {
      return combined.substring(0, 11);
    }
    if (combined.length == 8) return '974$combined';
    return combined;
  }

  static DepositPaymentIntent? extractDepositPaymentIntent(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    return DepositPaymentIntent.fromJson(payload);
  }

  static String? extractDepositPaymentStatus(Map<String, dynamic> response) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    final status = payload['payment_status'] ?? payload['status'];
    return status?.toString().toLowerCase();
  }

  static String? extractPayoutSuccessMessage(Map<String, dynamic> response) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    return _readNullableString(payload['message']);
  }

  static DriverWalletBalance? extractPayoutWalletBalance(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    final wallet = payload['wallet_balance'];
    if (wallet is! Map<String, dynamic>) return null;

    return DriverWalletBalance.fromPayoutResponse(wallet);
  }

  static Future<Map<String, dynamic>> requestDriverPayout({
    required double amount,
    required String bankAccountName,
    required String bankName,
    required String iban,
    required String accountNumber,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.driverRequestPayoutUrl),
            headers: headers,
            body: json.encode({
              'amount': amount,
              'bank_account_name': bankAccountName,
              'bank_name': bankName,
              'iban': iban,
              'account_number': accountNumber,
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> transferToCommissionWallet({
    required double amount,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.driverTransferToCommissionUrl),
            headers: headers,
            body: json.encode({'amount': amount}),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static DriverWalletBalance? extractTransferWalletBalance(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    final wallets = payload['wallets'];
    if (wallets is Map<String, dynamic>) {
      return DriverWalletBalance.fromJson(wallets);
    }

    if (_hasWalletBalanceFields(payload)) {
      return DriverWalletBalance.fromJson(payload);
    }

    final wallet = payload['wallet_balance'];
    if (wallet is Map<String, dynamic>) {
      return DriverWalletBalance.fromPayoutResponse(wallet);
    }

    return extractWalletBalance(response);
  }

  static bool _hasWalletBalanceFields(Map<String, dynamic> json) {
    return json.containsKey('main_wallet_balance') ||
        json.containsKey('commission_balance') ||
        json.containsKey('earnings_balance') ||
        json['main_wallet'] is Map<String, dynamic> ||
        json['commission_wallet'] is Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createDepositIntent({
    required String orderId,
    required double amount,
    required String customerName,
    required String email,
    required String mobile,
    String currency = 'QAR',
    bool isTest = true,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.processDepositUrl),
            headers: headers,
            body: json.encode({
              'action': 'create_intent',
              'order_id': orderId,
              'amount': amount,
              'currency': currency,
              'customer_name': customerName,
              'email': email,
              'mobile': mobile,
              'isTest': isTest,
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> getDepositPaymentStatus({
    required String paymentReference,
    String? tapChargeId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final queryParameters = <String, String>{
      'action': 'status',
      'payment_reference': paymentReference,
    };
    if (tapChargeId != null && tapChargeId.isNotEmpty) {
      queryParameters['tap_id'] = tapChargeId;
    }

    final uri = Uri.parse(ApiConfig.processDepositUrl).replace(
      queryParameters: queryParameters,
    );

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static String? extractMemberSinceFormatted(Map<String, dynamic> profile) {
    final account = profile['account_details'];
    if (account is Map<String, dynamic>) {
      final formatted = _readNullableString(account['member_since_formatted']);
      if (formatted != null) return formatted;
    }
    return _readNullableString(profile['member_since_formatted']);
  }

  static double? extractProfileRating(Map<String, dynamic> profile) {
    final rating = profile['rating'];
    if (rating is num) return rating.toDouble();
    return null;
  }

  /// First letter of the first and last name, e.g. "Okokon Ewomazino" -> "OE".
  static String initialsFromName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return '?';

    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    final firstInitial = parts.first.substring(0, 1).toUpperCase();
    final lastInitial = parts.last.substring(0, 1).toUpperCase();
    return '$firstInitial$lastInitial';
  }

  /// Resolves avatar URL from profile payload and normalizes storage paths.
  static String? extractAvatarUrl(Map<String, dynamic> profile) {
    var url = _readNullableUrl(profile['avatar_url']) ??
        _readNullableUrl(profile['photo']) ??
        _readNullableUrl(profile['profile_photo']);

    final personal = profile['personal_details'];
    if (url == null && personal is Map<String, dynamic>) {
      url = _readNullableUrl(personal['avatar_url']) ??
          _readNullableUrl(personal['photo']);
    }

    if (url == null) return null;
    return normalizeAvatarUrl(url);
  }

  static String normalizeAvatarUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final path = url.startsWith('/') ? url.substring(1) : url;
    if (path.startsWith('storage/v1/')) {
      return '${ApiConfig.supabaseUrl}/$path';
    }

    return '${ApiConfig.supabaseUrl}/storage/v1/object/public/$path';
  }

  /// Headers for loading images from Supabase storage (public or RLS-protected).
  static Map<String, String> get storageImageHeaders {
    final headers = <String, String>{'apikey': ApiConfig.supabaseAnonKey};
    final token = _accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final result = await _authorizedGet(Uri.parse(ApiConfig.getUserProfileUrl));
    await syncReferralFromAnyResponse(result);
    return result;
  }

  static Future<Map<String, dynamic>> editProfile({
    required String fullName,
    required String email,
    required String phone,
    required String dateOfBirth,
    String countryCode = ApiConfig.defaultCountryCode,
    String? avatarUrl,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final body = <String, dynamic>{
        'personal_details': {
          'full_name': fullName.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'date_of_birth': dateOfBirth.trim(),
        },
        'country_code': countryCode,
      };
      final photo = avatarUrl?.trim();
      if (photo != null && photo.isNotEmpty) {
        body['avatar_url'] = photo;
      }

      final response = await http
          .put(
            Uri.parse(ApiConfig.editProfileUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static String mimeTypeFromPath(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg';
    }
  }

  static String _rawBase64Payload(String fileBase64) {
    final commaIndex = fileBase64.indexOf(',');
    if (commaIndex != -1) {
      return fileBase64.substring(commaIndex + 1);
    }
    return fileBase64;
  }

  static Future<Map<String, dynamic>> uploadDocument({
    required String documentType,
    required String fileBase64,
    required String mimeType,
    int? fileSize,
  }) async {
    await ensureAuthenticatedSession();
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final body = <String, dynamic>{
      'document_type': documentType,
      'file_base64': _rawBase64Payload(fileBase64),
      'mime_type': mimeType,
    };
    if (fileSize != null) {
      body['file_size'] = fileSize;
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.uploadDocumentUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 60));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> deleteDocument({
    required String documentType,
  }) async {
    await ensureAuthenticatedSession();
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.deleteDocumentUrl),
            headers: headers,
            body: json.encode({'document_type': documentType}),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> uploadAvatar({
    required String base64Image,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.uploadAvatarUrl),
            headers: headers,
            body: json.encode({'base64_image': base64Image}),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static String? extractUploadedAvatarUrl(Map<String, dynamic> response) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    final url = payload['avatar_url'];
    if (url is String && url.trim().isNotEmpty) {
      return normalizeAvatarUrl(url.trim());
    }
    return null;
  }

  static Map<String, dynamic>? extractManageVehiclePayload(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    if (payload['vehicle'] is Map<String, dynamic> ||
        payload['vehicle_images'] is Map<String, dynamic>) {
      return payload;
    }

    final nested = data['data'];
    if (nested is Map<String, dynamic> &&
        (nested['vehicle'] is Map<String, dynamic> ||
            nested['vehicle_images'] is Map<String, dynamic>)) {
      return nested;
    }

    return null;
  }

  static String? extractVehicleImageUrl(Map<String, dynamic> payload) {
    final vehicle = payload['vehicle'];
    if (vehicle is Map<String, dynamic>) {
      final direct = _readNullableString(vehicle['vehicle_image']) ??
          _readNullableString(vehicle['image_url']) ??
          _readNullableString(vehicle['vehicle_image_url']);
      if (direct != null) return normalizeAvatarUrl(direct);
    }

    final images = payload['vehicle_images'];
    if (images is Map<String, dynamic>) {
      for (final key in [
        'vehicle_exterior',
        'vehicle_interior',
        'vehicle_front',
        'vehicle_side',
        'vehicle_back',
      ]) {
        final candidate = images[key];
        if (candidate is Map<String, dynamic>) {
          final fileUrl = _readNullableString(candidate['file_url']);
          if (fileUrl != null) return normalizeAvatarUrl(fileUrl);
        }
      }
    }

    return null;
  }

  static Map<String, String> extractVehicleFormFields(
    Map<String, dynamic> payload,
  ) {
    final vehicle = payload['vehicle'];
    final vehicleMap =
        vehicle is Map<String, dynamic> ? vehicle : <String, dynamic>{};

    String readField(List<String> keys) {
      for (final key in keys) {
        final value = vehicleMap[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    return {
      'make': readField(['make', 'vehicle_name']),
      'model': readField(['model', 'vehicle_model']),
      'year': readField(['year']),
      'color': readField(['color']),
      'license_plate': readField(['license_plate', 'plate_number']),
    };
  }

  static Future<Map<String, dynamic>> getManageVehicle() async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .get(Uri.parse(ApiConfig.manageVehicleUrl), headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> manageVehicle({
    required String make,
    required String model,
    required int year,
    required String color,
    required String licensePlate,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.manageVehicleUrl),
            headers: headers,
            body: json.encode({
              'make': make.trim(),
              'model': model.trim(),
              'year': year,
              'color': color.trim(),
              'license_plate': licensePlate.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static List<Map<String, dynamic>> extractNearbyRides(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return [];
    final data = response['data'];
    if (data is! Map<String, dynamic>) return [];

    final payload = unwrapAuthPayload(data);
    final rides = payload['rides'];
    if (rides is! List) return [];

    return rides
        .whereType<Map>()
        .map((ride) => Map<String, dynamic>.from(ride))
        .toList();
  }

  static Future<Map<String, dynamic>> getNearbyRides({
    required double driverLat,
    required double driverLng,
    double radiusKm = 5,
    int limit = 20,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.getNearbyRidesUrl),
            headers: headers,
            body: json.encode({
              'driver_lat': driverLat,
              'driver_lng': driverLng,
              'radius_km': radiusKm,
              'limit': limit,
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> getDriverRideStatus({
    String? rideId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final uri = Uri.parse(ApiConfig.driverRideStatusUrl).replace(
      queryParameters:
          rideId == null || rideId.isEmpty ? null : {'ride_id': rideId},
    );

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Map<String, dynamic>? extractDriverRideStatus(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    final ride = payload['ride'] ?? payload['active_ride'];
    if (ride is Map<String, dynamic>) return ride;
    if (ride is Map) return Map<String, dynamic>.from(ride);

    if (payload['id'] != null && payload['status'] != null) {
      return payload;
    }

    return null;
  }

  static DriverRideDetails? extractCompleteRideDetails(
    Map<String, dynamic> response, {
    double? distanceKm,
    int? durationMinutes,
    double? riderRating,
  }) {
    if (response['success'] != true) return null;

    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    if (payload['ride'] == null) return null;

    try {
      final details = DriverRideDetails.fromCompleteRidePayload(
        payload,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        riderRating: riderRating,
      );
      if (details.id.isEmpty) return null;
      return details;
    } on ArgumentError {
      return null;
    }
  }

  static Future<({DriverRideDetails? details, String? error})>
      fetchDriverRideDetails({
    required String rideId,
  }) async {
    final completedResponse =
        await getDriverCompletedTripDetails(rideId: rideId);
    if (completedResponse['success'] == true) {
      final completedDetails = extractCompletedTripDetails(completedResponse);
      if (completedDetails != null) {
        return (details: completedDetails, error: null);
      }
    }

    final statusResponse = await getDriverRideStatus(rideId: rideId);
    if (statusResponse['success'] != true) {
      return (
        details: null,
        error: extractErrorMessage(
          completedResponse['success'] == true ? statusResponse : completedResponse,
          fallback: AppStrings.current().errLoadRideDetails,
        ),
      );
    }

    final ride = extractDriverRideStatus(statusResponse);
    if (ride == null || (ride['id']?.toString() ?? '').isEmpty) {
      return (
        details: null,
        error: extractErrorMessage(
          completedResponse,
          fallback: AppStrings.current().errLoadRideDetails,
        ),
      );
    }

    double? paidAmount;
    final tripsResponse = await getDriverCompletedTrips(limit: 1, offset: 0);
    final tripsResult = extractCompletedTrips(tripsResponse);
    if (tripsResult != null) {
      for (final trip in tripsResult.trips) {
        if (trip.id == rideId) {
          paidAmount = trip.amount;
          break;
        }
      }
    }

    return (
      details: DriverRideDetails.fromRideStatus(
        ride,
        paidAmount: paidAmount,
      ),
      error: null,
    );
  }

  static Future<Map<String, dynamic>> driverArrivedPickup({
    required String rideId,
    required double latitude,
    required double longitude,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.driverArrivedPickupUrl),
            headers: headers,
            body: json.encode({
              'ride_id': rideId,
              'current_location': {
                'latitude': latitude,
                'longitude': longitude,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> startRide({
    required String rideId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.startRideUrl),
            headers: headers,
            body: json.encode({'ride_id': rideId}),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> completeRide({
    required String rideId,
    double? actualFare,
    String? completionNotes,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final body = <String, dynamic>{'ride_id': rideId};
    if (actualFare != null && actualFare > 0) {
      body['actual_fare'] = actualFare;
    }
    if (completionNotes != null && completionNotes.isNotEmpty) {
      body['completion_notes'] = completionNotes;
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.completeRideUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> getChatHistory({
    required String rideId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final uri = Uri.parse(ApiConfig.getChatHistoryUrl).replace(
      queryParameters: {'ride_id': rideId},
    );

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required String rideId,
    required String message,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final body = {
      'ride_id': rideId,
      'message': message,
    };

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.sendChatMessageUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Map<String, dynamic>? _chatPayload(Map<String, dynamic> response) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static List<Map<String, dynamic>> extractChatMessages(
    Map<String, dynamic> response,
  ) {
    final payload = _chatPayload(response);
    if (payload == null) return [];

    final nestedData = payload['data'];
    final candidates = [
      payload['messages'],
      if (nestedData is Map) nestedData['messages'],
    ];

    for (final messages in candidates) {
      if (messages is! List) continue;
      return messages
          .whereType<Map>()
          .map((message) => Map<String, dynamic>.from(message))
          .toList();
    }

    return [];
  }

  static bool extractCanSendMessages(Map<String, dynamic> response) {
    final payload = _chatPayload(response);
    if (payload == null) return false;

    final nestedData = payload['data'];
    final candidates = [
      payload['can_send_messages'],
      if (nestedData is Map) nestedData['can_send_messages'],
    ];

    for (final value in candidates) {
      if (value is bool) return value;
    }

    return true;
  }

  static Map<String, dynamic>? extractSentChatMessage(
    Map<String, dynamic> response,
  ) {
    final payload = _chatPayload(response);
    if (payload == null) return null;

    final message = payload['message'];
    if (message is Map<String, dynamic>) return message;
    if (message is Map) return Map<String, dynamic>.from(message);
    return null;
  }

  static Future<Map<String, dynamic>> cancelRide({
    required String rideId,
    String cancelledBy = 'driver',
    required String reason,
    String? reasonNote,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final payload = <String, dynamic>{
      'ride_id': rideId,
      'cancelled_by': cancelledBy,
      'reason': reason,
    };
    if (reasonNote != null && reasonNote.trim().isNotEmpty) {
      payload['reason_note'] = reasonNote.trim();
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.cancelRideUrl),
            headers: headers,
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static bool isRideAlreadyCancelledResponse(Map<String, dynamic> response) {
    if (response['success'] == true) return false;

    final message = extractErrorMessage(response).toLowerCase();
    return (message.contains('already') && message.contains('cancel')) ||
        message.contains('already been cancel') ||
        message.contains('ride has been cancel') ||
        message.contains('ride was cancel') ||
        message.contains('no longer available') ||
        message.contains('not available') ||
        message.contains('ride not found');
  }

  static bool isRideAlreadyAcceptedResponse(Map<String, dynamic> response) {
    if (response['success'] == true) return false;

    final message = extractErrorMessage(response).toLowerCase();
    return (message.contains('already') && message.contains('accept')) ||
        message.contains('already been accept') ||
        message.contains('already assigned') ||
        message.contains('assigned to you') ||
        message.contains('ride is not pending') ||
        message.contains('not pending') ||
        message.contains('cannot accept');
  }

  static Future<Map<String, dynamic>> rideResponse({
    required String rideId,
    required String action,
    double? latitude,
    double? longitude,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final payload = <String, dynamic>{
      'ride_id': rideId,
      'action': action,
    };

    if (latitude != null && longitude != null) {
      payload['current_location'] = {
        'latitude': latitude,
        'longitude': longitude,
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.rideResponseUrl),
            headers: headers,
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> getMySupportTickets({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final queryParameters = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    final normalizedStatus = status?.trim().toLowerCase();
    if (normalizedStatus != null &&
        normalizedStatus.isNotEmpty &&
        normalizedStatus != 'all') {
      queryParameters['status'] = normalizedStatus;
    }

    final uri = Uri.parse(ApiConfig.mySupportTicketsUrl).replace(
      queryParameters: queryParameters,
    );

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static SupportTicketsResult? extractMySupportTickets(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    final ticketsRaw = payload['tickets'] ??
        payload['support_tickets'] ??
        data['tickets'] ??
        data['support_tickets'];
    final tickets = ticketsRaw is List
        ? ticketsRaw
            .whereType<Map>()
            .map(
              (ticket) => SupportTicket.fromJson(
                Map<String, dynamic>.from(ticket),
              ),
            )
            .where((ticket) => ticket.id.isNotEmpty)
            .toList()
        : <SupportTicket>[];

    final pagination = payload['pagination'] ?? data['pagination'];
    final page = pagination is Map<String, dynamic>
        ? _readTripPaginationInt(pagination['page'], fallback: 1)
        : 1;
    final limit = pagination is Map<String, dynamic>
        ? _readTripPaginationInt(pagination['limit'], fallback: tickets.length)
        : tickets.length;
    final totalCount = pagination is Map<String, dynamic>
        ? _readTripPaginationInt(
            pagination['total_count'] ?? pagination['total'],
            fallback: tickets.length,
          )
        : _readTripPaginationInt(
            payload['total_count'] ?? data['total_count'],
            fallback: tickets.length,
          );
    final hasMore = pagination is Map<String, dynamic>
        ? pagination['has_more'] == true
        : page * (limit == 0 ? 1 : limit) < totalCount;

    return SupportTicketsResult(
      tickets: tickets,
      page: page,
      limit: limit,
      hasMore: hasMore,
      totalCount: totalCount,
    );
  }

  static Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String description,
    required String category,
    List<SupportTicketAttachmentPayload>? attachments,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final body = <String, dynamic>{
      'subject': subject.trim(),
      'description': description.trim(),
      'category': category.trim(),
    };
    if (attachments != null && attachments.isNotEmpty) {
      body['attachments'] = attachments.map((item) => item.toJson()).toList();
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.createSupportTicketUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static SupportTicket? extractCreatedSupportTicket(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    final nested = payload['data'];
    final root = nested is Map<String, dynamic> ? nested : payload;
    final ticketRaw = root['ticket'] ?? payload['ticket'] ?? data['ticket'];

    if (ticketRaw is Map<String, dynamic>) {
      return SupportTicket.fromJson(ticketRaw);
    }
    if (ticketRaw is Map) {
      return SupportTicket.fromJson(Map<String, dynamic>.from(ticketRaw));
    }

    if (root['id'] != null || root['ticket_id'] != null) {
      return SupportTicket.fromJson(root);
    }

    return null;
  }

  static Future<Map<String, dynamic>> getSupportTicketConversation({
    required String ticketId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final uri = Uri.parse(ApiConfig.supportTicketConversationUrl).replace(
      queryParameters: {'ticket_id': ticketId},
    );

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> replyToSupportTicket({
    required String ticketId,
    required String message,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final uri = Uri.parse(ApiConfig.supportTicketConversationUrl).replace(
      queryParameters: {'ticket_id': ticketId},
    );

    try {
      final response = await http
          .post(
            uri,
            headers: headers,
            body: json.encode({'message': message}),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static SupportTicketConversation? extractSupportTicketConversation(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;

    final payload = unwrapAuthPayload(data);
    final nested = payload['data'];
    final root = nested is Map<String, dynamic> ? nested : payload;

    final messagesRaw = root['messages'] ??
        root['conversation'] ??
        payload['messages'] ??
        data['messages'];
    final messages = messagesRaw is List
        ? messagesRaw
            .whereType<Map>()
            .map(
              (message) => SupportTicketMessage.fromJson(
                Map<String, dynamic>.from(message),
              ),
            )
            .where((message) => message.id.isNotEmpty && message.message.isNotEmpty)
            .toList()
        : <SupportTicketMessage>[];

    final ticketRaw = root['ticket'] ?? payload['ticket'] ?? data['ticket'];
    final ticket = ticketRaw is Map<String, dynamic>
        ? SupportTicket.fromJson(ticketRaw)
        : ticketRaw is Map
            ? SupportTicket.fromJson(Map<String, dynamic>.from(ticketRaw))
            : null;

    final canReply = _readSupportTicketCanReply(root) ??
        _readSupportTicketCanReply(payload) ??
        _readSupportTicketCanReply(data) ??
        true;

    return SupportTicketConversation(
      messages: messages,
      ticket: ticket,
      canReply: canReply,
    );
  }

  static bool? _readSupportTicketCanReply(Map<String, dynamic> payload) {
    final value = payload['can_reply'] ?? payload['can_send_message'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }

  static List<DriverNotification> extractDriverNotifications(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return [];
    final data = response['data'];
    if (data is! Map<String, dynamic>) return [];

    final payload = unwrapAuthPayload(data);
    final notifications = payload['notifications'] ?? data['notifications'];
    if (notifications is! List) return [];

    return notifications
        .whereType<Map>()
        .map((item) => DriverNotification.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((notification) => notification.id.isNotEmpty)
        .toList();
  }

  static Future<Map<String, dynamic>> getDriverNotifications({
    int limit = 20,
    String? type,
    bool? includeCompletedTransactions,
    bool? includeCompletedRides,
    bool includeRead = false,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final queryParameters = <String, String>{'limit': '$limit'};
    final trimmedType = type?.trim();
    if (trimmedType != null && trimmedType.isNotEmpty) {
      queryParameters['type'] = trimmedType;
    }
    if (includeCompletedTransactions != null) {
      queryParameters['include_completed_transactions'] =
          includeCompletedTransactions.toString();
    }
    if (includeCompletedRides != null) {
      queryParameters['include_completed_rides'] =
          includeCompletedRides.toString();
    }
    if (includeRead) {
      queryParameters['include_read'] = 'true';
    }

    final uri = Uri.parse(ApiConfig.riderNotificationsUrl).replace(
      queryParameters: queryParameters,
    );

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  /// Admin private messages (`notification_type: system`) for support chat.
  static Future<Map<String, dynamic>> getAdminSystemNotifications({
    int limit = 50,
    bool includeRead = true,
  }) {
    return getDriverNotifications(
      type: 'system',
      limit: limit,
      includeCompletedTransactions: false,
      includeCompletedRides: false,
      includeRead: includeRead,
    );
  }

  static List<DriverNotification> extractUnreadAdminNotifications(
    Map<String, dynamic> response,
  ) {
    return extractDriverNotifications(response)
        .where(
          (notification) =>
              !notification.isRead && notification.message.trim().isNotEmpty,
        )
        .toList();
  }

  static Future<Map<String, dynamic>> markNotificationsAsRead({
    required List<String> notificationIds,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    if (notificationIds.isEmpty) {
      return {'success': true};
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.riderNotificationsUrl),
            headers: headers,
            body: json.encode({'notification_ids': notificationIds}),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static bool isNotFoundCallEndError(Map<String, dynamic>? response) {
    if (response == null || response['success'] == true) return false;
    final error = response['error'];
    final message = extractErrorMessage(response).toLowerCase();
    String? code;
    if (error is Map) {
      code = error['code']?.toString().toLowerCase();
    }
    return code == 'not_found' ||
        code == 'call_not_found' ||
        message.contains('not found') ||
        message.contains('no active call');
  }

  static Future<Map<String, dynamic>> startCall({
    required String rideId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.callsStartUrl),
            headers: headers,
            body: json.encode({'ride_id': rideId}),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static CallStartData? extractCallStartData(Map<String, dynamic> response) {
    if (response['success'] != true) return null;
    try {
      return parseCallStartData(response);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getZegoToken({
    required String rideId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.rtcZegoTokenUrl),
            headers: headers,
            body: json.encode({'ride_id': rideId}),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static RtcZegoSessionData? extractZegoSessionData(
    Map<String, dynamic> response,
  ) {
    if (response['success'] != true) return null;
    try {
      return parseRtcZegoSessionData(response);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> refreshZegoToken({
    required String rideId,
    required String roomId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.rtcZegoRefreshUrl),
            headers: headers,
            body: json.encode({
              'ride_id': rideId,
              'room_id': roomId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> endCall({
    String? callId,
    String? rideId,
    String reason = 'ended_by_user',
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final body = <String, dynamic>{'reason': reason};
    if (callId != null && callId.isNotEmpty) body['call_id'] = callId;
    if (rideId != null && rideId.isNotEmpty) body['ride_id'] = rideId;

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.callsEndUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> registerFcmToken({
    required String deviceToken,
    required String deviceType,
    String? deviceId,
  }) async {
    await refreshSessionIfNeeded();

    final headers = _authorizedHeaders;
    if (headers == null) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    final body = <String, dynamic>{
      'device_token': deviceToken,
      'device_type': deviceType,
      'user_type': 'driver',
    };
    if (deviceId != null && deviceId.isNotEmpty) {
      body['device_id'] = deviceId;
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.registerFcmTokenUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  /// POST /functions/v1/delete-account
  /// Headers: Authorization Bearer, apikey, Content-Type application/json
  static Future<Map<String, dynamic>> deleteAccount() async {
    stopSessionRefresh();
    await refreshSessionIfNeeded();

    final token = _accessToken;
    if (token == null || token.isEmpty) {
      return {
        'success': false,
        'error': {'message': 'Not logged in. Please sign in again.'},
      };
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.deleteAccountUrl),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 30));

      final result = _handleResponse(response);
      if (result['success'] == true) {
        await signOut();
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    stopSessionRefresh();
    final token = _accessToken;
    try {
      if (token != null && token.isNotEmpty) {
        final response = await http
            .post(
              Uri.parse(ApiConfig.logoutUrl),
              headers: _authHeaders(token),
            )
            .timeout(const Duration(seconds: 15));

        final result = _handleResponse(response);
        await signOut();
        return result;
      }

      await signOut();
      return {'success': true};
    } catch (e) {
      await signOut();
      return {
        'success': false,
        'error': {'message': 'Network error: $e'},
      };
    }
  }
}
