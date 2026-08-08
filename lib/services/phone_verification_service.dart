import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'push_notification_service.dart';

class PhoneVerificationException implements Exception {
  PhoneVerificationException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '$code: $message';
}

class PhoneVerificationSendSession {
  PhoneVerificationSendSession({
    required this.immediateResult,
    required this.lateAutoVerifyStarted,
    required this.lateAutoVerify,
    required this.manualEntryReady,
    required this.autoRetrievalTimedOut,
  });

  final Future<Map<String, dynamic>> immediateResult;
  final Stream<void> lateAutoVerifyStarted;
  final Stream<Map<String, dynamic>> lateAutoVerify;
  /// Fires when [codeSent] provides a [verificationId] for manual OTP entry.
  final Stream<void> manualEntryReady;
  /// Fires when Android SMS auto-read times out — user must type the code.
  final Stream<void> autoRetrievalTimedOut;
}

class PhoneVerificationService {
  PhoneVerificationService._();

  static String? _verificationId;
  static int? _resendToken;
  static int _activeSessionId = 0;
  static var _autoVerifyInProgress = false;
  static StreamController<Map<String, dynamic>>? _lateAutoVerifyController;
  static StreamController<void>? _lateAutoVerifyStartedController;
  static StreamController<void>? _manualEntryReadyController;
  static StreamController<void>? _autoRetrievalTimedOutController;
  static Future<Map<String, dynamic>>? _activeConfirmFuture;
  static int? _activeConfirmSessionId;
  static String? _verificationEmail;

  static const _persistedVerificationIdKey = 'firebase_verification_id';
  static const _persistedResendTokenKey = 'firebase_resend_token';
  static const _persistedVerificationPhoneKey = 'firebase_verification_phone';
  static const _persistedVerificationAtKey = 'firebase_verification_at_ms';
  static const _verificationSessionTtl = Duration(minutes: 10);

  static bool get canSubmitManualCode =>
      !_autoVerifyInProgress &&
      _verificationId != null &&
      _verificationId!.isNotEmpty;

  static String toE164(String phone) {
    final digits = AuthService.normalizeMobileForDeposit(phone: phone);
    if (digits.isEmpty) return '';
    return '+$digits';
  }

  static bool _isActiveSession(int sessionId) => sessionId == _activeSessionId;

  static Future<void> _waitForInFlightWork() async {
    final confirm = _activeConfirmFuture;
    if (confirm != null) {
      try {
        await confirm;
      } catch (_) {
        // Previous session errors should not block a new send.
      }
    }
  }

  static Future<void> _beginSession() async {
    await _waitForInFlightWork();
    await _signOutFirebase();
    _activeSessionId++;
    _verificationId = null;
    _autoVerifyInProgress = false;
    _activeConfirmFuture = null;
    _activeConfirmSessionId = null;
    _lateAutoVerifyController?.close();
    _lateAutoVerifyStartedController?.close();
    _lateAutoVerifyController = StreamController<Map<String, dynamic>>();
    _lateAutoVerifyStartedController = StreamController<void>();
    _manualEntryReadyController?.close();
    _autoRetrievalTimedOutController?.close();
    _manualEntryReadyController = StreamController<void>.broadcast();
    _autoRetrievalTimedOutController = StreamController<void>.broadcast();
  }

  static void _emitManualEntryReady(int sessionId) {
    if (!_isActiveSession(sessionId)) return;
    final controller = _manualEntryReadyController;
    if (controller != null && !controller.isClosed) {
      controller.add(null);
    }
  }

  static void _emitAutoRetrievalTimedOut(int sessionId) {
    if (!_isActiveSession(sessionId)) return;
    final controller = _autoRetrievalTimedOutController;
    if (controller != null && !controller.isClosed) {
      controller.add(null);
    }
  }

  static void _closeLateAutoVerifyStream() {
    final controller = _lateAutoVerifyController;
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    final startedController = _lateAutoVerifyStartedController;
    if (startedController != null && !startedController.isClosed) {
      startedController.close();
    }
  }

  static void _emitLateAutoVerifyStarted(int sessionId) {
    if (!_isActiveSession(sessionId)) return;
    final startedController = _lateAutoVerifyStartedController;
    if (startedController != null && !startedController.isClosed) {
      startedController.add(null);
    }
  }

  static Future<void> _emitLateAutoVerifyResult(
    int sessionId,
    Future<Map<String, dynamic>> resultFuture,
  ) async {
    final lateController = _lateAutoVerifyController;
    try {
      final result = await resultFuture;
      if (_isActiveSession(sessionId) &&
          lateController != null &&
          !lateController.isClosed) {
        lateController.add(result);
      }
    } catch (error) {
      if (_isActiveSession(sessionId) &&
          lateController != null &&
          !lateController.isClosed) {
        lateController.add(_errorResultFrom(error));
      }
    } finally {
      if (_isActiveSession(sessionId)) {
        _autoVerifyInProgress = false;
      }
      _closeLateAutoVerifyStream();
    }
  }

  static Map<String, dynamic> _codeSentResponse(String phone) {
    return {
      'success': true,
      'data': {
        'message': 'Verification code sent.',
        'phone_number': AuthService.normalizeMobileForDeposit(phone: phone),
        'provider': 'firebase',
        'sms_sent': true,
      },
    };
  }

  static Future<void> _persistVerificationSession({
    required String phone,
    required String verificationId,
    int? resendToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_persistedVerificationIdKey, verificationId);
    await prefs.setString(
      _persistedVerificationPhoneKey,
      AuthService.normalizeMobileForDeposit(phone: phone),
    );
    await prefs.setInt(
      _persistedVerificationAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (resendToken != null) {
      await prefs.setInt(_persistedResendTokenKey, resendToken);
    } else {
      await prefs.remove(_persistedResendTokenKey);
    }
  }

  static Future<void> clearPersistedVerificationSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_persistedVerificationIdKey);
    await prefs.remove(_persistedResendTokenKey);
    await prefs.remove(_persistedVerificationPhoneKey);
    await prefs.remove(_persistedVerificationAtKey);
  }

  static Future<PhoneVerificationSendSession?> _tryRestorePersistedSession(
    String phone,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final verificationId = prefs.getString(_persistedVerificationIdKey);
    final storedPhone = prefs.getString(_persistedVerificationPhoneKey);
    final savedAtMs = prefs.getInt(_persistedVerificationAtKey);
    if (verificationId == null ||
        verificationId.isEmpty ||
        storedPhone == null ||
        savedAtMs == null) {
      return null;
    }

    final normalizedPhone = AuthService.normalizeMobileForDeposit(phone: phone);
    if (storedPhone != normalizedPhone) return null;

    final age = DateTime.now().millisecondsSinceEpoch - savedAtMs;
    if (age > _verificationSessionTtl.inMilliseconds) {
      await clearPersistedVerificationSession();
      return null;
    }

    _verificationId = verificationId;
    final resendToken = prefs.getInt(_persistedResendTokenKey);
    _resendToken = resendToken;

    final manualEntryController = StreamController<void>.broadcast();
    manualEntryController.add(null);

    final restoredData = Map<String, dynamic>.from(
      _codeSentResponse(phone)['data'] as Map,
    );
    restoredData['message'] = 'Enter the verification code from your SMS.';
    restoredData['restored'] = true;

    return PhoneVerificationSendSession(
      immediateResult: Future.value({'success': true, 'data': restoredData}),
      lateAutoVerifyStarted: const Stream<void>.empty(),
      lateAutoVerify: const Stream<Map<String, dynamic>>.empty(),
      manualEntryReady: manualEntryController.stream,
      autoRetrievalTimedOut: const Stream<void>.empty(),
    );
  }

  static void _markCodeReady({
    required int sessionId,
    required String phone,
    required String verificationId,
    int? resendToken,
    required Completer<Map<String, dynamic>> immediateCompleter,
    required void Function() onCodeSent,
    required bool emitAutoRetrievalTimedOut,
  }) {
    if (!_isActiveSession(sessionId)) return;

    onCodeSent();
    _verificationId = verificationId;
    if (resendToken != null) {
      _resendToken = resendToken;
    }

    unawaited(
      _persistVerificationSession(
        phone: phone,
        verificationId: verificationId,
        resendToken: resendToken ?? _resendToken,
      ),
    );

    _emitManualEntryReady(sessionId);
    if (emitAutoRetrievalTimedOut) {
      _emitAutoRetrievalTimedOut(sessionId);
    }

    if (!immediateCompleter.isCompleted) {
      immediateCompleter.complete(_codeSentResponse(phone));
    }
  }

  static Future<void> _ensureIosApnsReadyForPhoneAuth() async {
    if (!Platform.isIOS) return;

    await PushNotificationService.prepareIosForPhoneAuth();

    const maxAttempts = 40;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final token = await FirebaseMessaging.instance.getAPNSToken();
      if (token != null && token.isNotEmpty) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Sends an SMS code via Firebase Auth.
  ///
  /// [immediateResult] completes on [codeSent] (SMS dispatched) or early
  /// [verificationCompleted] (instant auto-verify on Android).
  ///
  /// [lateAutoVerify] emits once when [verificationCompleted] finishes after
  /// [codeSent] already delivered the immediate result.
  static Future<PhoneVerificationSendSession> sendCode(
    String phone, {
    String? email,
    bool forceResend = false,
  }) async {
    final e164 = toE164(phone);
    if (e164.isEmpty) {
      throw PhoneVerificationException('Invalid phone number.');
    }

    _verificationEmail = email?.trim();

    if (forceResend) {
      await clearPersistedVerificationSession();
    } else {
      final restored = await _tryRestorePersistedSession(phone);
      if (restored != null) {
        return restored;
      }
    }

    await _beginSession();
    await _ensureIosApnsReadyForPhoneAuth();
    final sessionId = _activeSessionId;
    final lateController = _lateAutoVerifyController!;
    final startedController = _lateAutoVerifyStartedController!;
    final manualEntryController = _manualEntryReadyController!;
    final autoRetrievalTimedOutController = _autoRetrievalTimedOutController!;
    final immediateCompleter = Completer<Map<String, dynamic>>();
    var codeSent = false;

    unawaited(
      FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResend ? _resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!_isActiveSession(sessionId)) return;

          try {
            if (!immediateCompleter.isCompleted) {
              final result = await _completeVerificationForPhone(
                phone,
                sessionId: sessionId,
                credential: credential,
              );
              if (!_isActiveSession(sessionId)) return;
              if (!immediateCompleter.isCompleted) {
                immediateCompleter.complete(result);
              }
              _closeLateAutoVerifyStream();
              return;
            }

            _autoVerifyInProgress = true;
            _emitLateAutoVerifyStarted(sessionId);
            await _emitLateAutoVerifyResult(
              sessionId,
              _completeVerificationForPhone(
                phone,
                sessionId: sessionId,
                credential: credential,
              ),
            );
          } catch (error) {
            if (!_isActiveSession(sessionId)) return;
            if (!immediateCompleter.isCompleted) {
              immediateCompleter.completeError(error);
            } else if (!lateController.isClosed) {
              lateController.add(_errorResultFrom(error));
              _closeLateAutoVerifyStream();
            }
          } finally {
            if (_isActiveSession(sessionId)) {
              _autoVerifyInProgress = false;
            }
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!_isActiveSession(sessionId)) return;
          if (!immediateCompleter.isCompleted) {
            immediateCompleter.completeError(
              PhoneVerificationException(
                _mapPhoneVerificationFailure(error),
                code: error.code,
              ),
            );
          }
          _closeLateAutoVerifyStream();
        },
        codeSent: (String verificationId, int? resendToken) {
          _markCodeReady(
            sessionId: sessionId,
            phone: phone,
            verificationId: verificationId,
            resendToken: resendToken,
            immediateCompleter: immediateCompleter,
            onCodeSent: () => codeSent = true,
            emitAutoRetrievalTimedOut: false,
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _markCodeReady(
            sessionId: sessionId,
            phone: phone,
            verificationId: verificationId,
            resendToken: _resendToken,
            immediateCompleter: immediateCompleter,
            onCodeSent: () => codeSent = true,
            emitAutoRetrievalTimedOut: true,
          );
        },
      ),
    );

    final immediateResult = immediateCompleter.future.timeout(
      const Duration(seconds: 65),
      onTimeout: () {
        if (codeSent &&
            _verificationId != null &&
            _verificationId!.isNotEmpty) {
          return _codeSentResponse(phone);
        }
        throw PhoneVerificationException(
          codeSent
              ? 'Verification is taking longer than expected. Try resending the code.'
              : 'Timed out waiting for Firebase to send the verification code.',
          code: 'timeout',
        );
      },
    );

    return PhoneVerificationSendSession(
      immediateResult: immediateResult,
      lateAutoVerifyStarted: startedController.stream,
      lateAutoVerify: lateController.stream,
      manualEntryReady: manualEntryController.stream,
      autoRetrievalTimedOut: autoRetrievalTimedOutController.stream,
    );
  }

  static Future<Map<String, dynamic>> verifyCodeAndConfirm({
    required String phone,
    required String smsCode,
    String? email,
  }) async {
    if (_autoVerifyInProgress) {
      return {
        'success': false,
        'error': {
          'message': 'Please wait, verifying your number automatically.',
        },
      };
    }

    if (email != null && email.trim().isNotEmpty) {
      _verificationEmail = email.trim();
    }

    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      final existingUser = FirebaseAuth.instance.currentUser;
      if (existingUser != null) {
        return _completeVerificationForPhone(
          phone,
          sessionId: _activeSessionId,
        );
      }

      return {
        'success': false,
        'error': {
          'message':
              'Waiting for a new verification code. Tap Resend Code if this takes too long.',
        },
      };
    }

    final trimmedCode = smsCode.trim();
    if (trimmedCode.length != 6) {
      return {
        'success': false,
        'error': {
          'message': 'Please enter the full 6-digit verification code.',
        },
      };
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: trimmedCode,
      );
      return await _completeVerificationForPhone(
        phone,
        sessionId: _activeSessionId,
        credential: credential,
      );
    } on FirebaseAuthException catch (error) {
      if (_isCodeAlreadyUsedError(error)) {
        _verificationId = null;
      }
      return {
        'success': false,
        'error': {
          'message': _mapFirebaseAuthError(error),
          'code': error.code,
        },
      };
    } on PhoneVerificationException catch (error) {
      return {
        'success': false,
        'error': {
          'message': error.message,
          if (error.code != null) 'code': error.code,
        },
      };
    } catch (error) {
      return {
        'success': false,
        'error': {'message': 'Verification failed. Please try again.'},
      };
    }
  }

  static Future<Map<String, dynamic>> _completeVerificationForPhone(
    String phone, {
    required int sessionId,
    PhoneAuthCredential? credential,
  }) async {
    if (!_isActiveSession(sessionId)) {
      throw PhoneVerificationException(
        'Verification session expired. Tap Resend Code and try again.',
        code: 'session-expired',
      );
    }

    if (_activeConfirmFuture != null && _activeConfirmSessionId == sessionId) {
      return _activeConfirmFuture!;
    }

    final confirmFuture = _runConfirmForPhone(
      phone,
      sessionId: sessionId,
      credential: credential,
    );
    _activeConfirmFuture = confirmFuture;
    _activeConfirmSessionId = sessionId;

    try {
      return await confirmFuture;
    } finally {
      if (_activeConfirmSessionId == sessionId) {
        _activeConfirmFuture = null;
        _activeConfirmSessionId = null;
      }
    }
  }

  static Future<Map<String, dynamic>> _runConfirmForPhone(
    String phone, {
    required int sessionId,
    PhoneAuthCredential? credential,
  }) async {
    if (credential != null) {
      await FirebaseAuth.instance.signInWithCredential(credential);
    }

    if (!_isActiveSession(sessionId)) {
      await _signOutFirebase();
      throw PhoneVerificationException(
        'Verification session expired. Tap Resend Code and try again.',
        code: 'session-expired',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw PhoneVerificationException(
        'Could not verify your phone number. Tap Resend Code and try again.',
      );
    }

    final firebaseIdToken = await user.getIdToken(true);
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      await _signOutFirebase();
      throw PhoneVerificationException(
        'Could not get a Firebase verification token.',
      );
    }

    final result = await AuthService.confirmPhoneVerification(
      firebaseIdToken: firebaseIdToken,
      phoneNumber: phone,
      email: _verificationEmail,
    );

    await _signOutFirebase();

    if (result['success'] == true) {
      _verificationId = null;
      _resendToken = null;
      await clearPersistedVerificationSession();
    } else {
      _verificationId = null;
      return {
        ...result,
        'firebase_code_consumed': true,
      };
    }

    return result;
  }

  static bool _isCodeAlreadyUsedError(FirebaseAuthException error) {
    switch (error.code) {
      case 'code-expired':
      case 'session-expired':
      case 'invalid-verification-code':
        return true;
      default:
        return false;
    }
  }

  static Future<void> _signOutFirebase() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Non-blocking cleanup after backend confirmation.
    }
  }

  static String _mapPhoneVerificationFailure(FirebaseAuthException error) {
    switch (error.code) {
      case 'too-many-requests':
        return 'Firebase has temporarily blocked this device after too many attempts. '
            'Wait a few hours, use a different phone, or add a test number in Firebase Console.';
      default:
        return error.message ?? 'Could not send verification code.';
    }
  }

  static String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'code-expired':
      case 'session-expired':
      case 'invalid-verification-code':
        return 'This code has expired or was already used. Tap Resend Code to get a new one.';
      default:
        return error.message ?? 'Invalid verification code.';
    }
  }

  static Map<String, dynamic> _errorResultFrom(Object error) {
    if (error is PhoneVerificationException) {
      return {
        'success': false,
        'error': {
          'message': error.message,
          if (error.code != null) 'code': error.code,
        },
      };
    }
    if (error is FirebaseAuthException) {
      if (_isActiveSession(_activeSessionId) && _isCodeAlreadyUsedError(error)) {
        _verificationId = null;
      }
      return {
        'success': false,
        'error': {
          'message': _mapFirebaseAuthError(error),
          'code': error.code,
        },
      };
    }
    return {
      'success': false,
      'error': {'message': 'Verification failed. Please try again.'},
    };
  }
}
