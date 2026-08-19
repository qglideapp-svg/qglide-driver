import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app_strings.dart';
import '../../../services/auth_service.dart';
import '../../../services/phone_verification_service.dart';

class VerificationController extends ChangeNotifier {
  VerificationController({
    required this.phoneNumber,
    required this.normalizedPhone,
    this.email,
    this.firebasePhoneE164,
    this.requireFreshSms = false,
  });

  final String phoneNumber;
  final String normalizedPhone;
  final String? email;
  final String? firebasePhoneE164;
  final bool requireFreshSms;
  final digitControllers = List.generate(6, (_) => TextEditingController());
  final focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _autoVerifySub;
  StreamSubscription<void>? _autoVerifyStartedSub;
  StreamSubscription<void>? _manualEntryReadySub;
  StreamSubscription<void>? _autoRetrievalTimedOutSub;
  var _secondsRemaining = 45;
  var _isSendingCode = false;
  var _isConfirming = false;
  var _isAutoVerifying = false;
  var _isWaitingForCode = true;
  var _codeReadyForEntry = false;
  var _autoReadTimedOut = false;
  var _otpSubmitLocked = false;
  String? _errorMessage;

  void Function(Map<String, dynamic> result)? onAutoVerifyComplete;

  int get secondsRemaining => _secondsRemaining;
  bool get canResend =>
      !_isSendingCode &&
      !_isAutoVerifying &&
      (_secondsRemaining <= 0 || !_isWaitingForCode && !PhoneVerificationService.canSubmitManualCode);
  bool get isSendingCode => _isSendingCode;
  bool get isConfirming => _isConfirming;
  bool get isAutoVerifying => _isAutoVerifying;
  bool get isWaitingForCode => _isWaitingForCode;
  bool get codeReadyForEntry => _codeReadyForEntry;
  bool get autoReadTimedOut => _autoReadTimedOut;
  String get instructionText {
    final s = AppStrings.current();
    if (_isAutoVerifying) {
      return s.instructionVerifyingAuto;
    }
    if (_isSendingCode || _isWaitingForCode) {
      return s.instructionSendingCode;
    }
    if (_autoReadTimedOut) {
      return s.instructionManualTimedOut;
    }
    return s.instructionEnterCode;
  }
  bool get canConfirm =>
      !_otpSubmitLocked &&
      !_isSendingCode &&
      !_isConfirming &&
      !_isAutoVerifying &&
      hasCompleteOtp &&
      PhoneVerificationService.canSubmitManualCode;
  bool get isBusy =>
      _isSendingCode || _isConfirming || _isAutoVerifying || _isWaitingForCode;
  String? get errorMessage => _errorMessage;

  String get timerText {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get otpCode =>
      digitControllers.map((controller) => controller.text).join();

  String get apiPhoneNumber => normalizedPhone.isNotEmpty
      ? normalizedPhone
      : AuthService.normalizeDriverPhone(phone: phoneNumber);

  Future<Map<String, dynamic>> sendCode({bool forceResend = false}) async {
    if (_isSendingCode) {
      return {
        'success': false,
        'error': {'message': AppStrings.current().errCodeAlreadySending},
      };
    }

    if (apiPhoneNumber.length < 11) {
      return {
        'success': false,
        'error': {
          'message': AppStrings.current().errInvalidPhoneSignup,
        },
      };
    }

    _isSendingCode = true;
    _isWaitingForCode = true;
    _codeReadyForEntry = false;
    _autoReadTimedOut = false;
    _otpSubmitLocked = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await PhoneVerificationService.sendCode(
        apiPhoneNumber,
        email: email,
        firebasePhoneE164: firebasePhoneE164,
        forceResend: forceResend,
        allowSessionRestore: !requireFreshSms,
      );
      _listenForVerificationSession(
        started: session.lateAutoVerifyStarted,
        result: session.lateAutoVerify,
        manualEntryReady: session.manualEntryReady,
        autoRetrievalTimedOut: session.autoRetrievalTimedOut,
      );

      final result = await session.immediateResult;
      if (_isBackendAutoVerifyResponse(result)) {
        _isWaitingForCode = false;
      } else if (result['success'] == true) {
        _codeReadyForEntry = true;
        _isWaitingForCode = !PhoneVerificationService.canSubmitManualCode;
        _startTimer();
      } else {
        _isWaitingForCode = false;
      }
      return result;
    } on PhoneVerificationException catch (error) {
      _errorMessage = error.message;
      _isWaitingForCode = false;
      return {
        'success': false,
        'error': {'message': error.message},
      };
    } catch (error) {
      _errorMessage = AppStrings.current().errSendCodeRetry;
      _isWaitingForCode = false;
      return {
        'success': false,
        'error': {'message': _errorMessage},
      };
    } finally {
      _isSendingCode = false;
      if (PhoneVerificationService.canSubmitManualCode) {
        _codeReadyForEntry = true;
        _isWaitingForCode = false;
      }
      notifyListeners();
    }
  }

  void _listenForVerificationSession({
    required Stream<void> started,
    required Stream<Map<String, dynamic>> result,
    required Stream<void> manualEntryReady,
    required Stream<void> autoRetrievalTimedOut,
  }) {
    _cancelSessionListeners();
    _manualEntryReadySub = manualEntryReady.listen((_) {
      _codeReadyForEntry = true;
      _isWaitingForCode = false;
      notifyListeners();
    });
    _autoRetrievalTimedOutSub = autoRetrievalTimedOut.listen((_) {
      _autoReadTimedOut = true;
      _codeReadyForEntry = true;
      _isWaitingForCode = false;
      notifyListeners();
    });
    _autoVerifyStartedSub = started.listen((_) {
      _isAutoVerifying = true;
      _isWaitingForCode = false;
      notifyListeners();
    });

    _autoVerifySub = result.listen((verificationResult) async {
      try {
        if (verificationResult['success'] != true) {
          _errorMessage = AuthService.extractErrorMessage(
            verificationResult,
            fallback: AppStrings.current().errAutoVerification,
          );
        }
        onAutoVerifyComplete?.call(verificationResult);
      } finally {
        _isAutoVerifying = false;
        _isWaitingForCode = !PhoneVerificationService.canSubmitManualCode;
        if (!PhoneVerificationService.canSubmitManualCode) {
          _secondsRemaining = 0;
        }
        notifyListeners();
      }
    });
  }

  void _cancelSessionListeners() {
    unawaited(_autoVerifyStartedSub?.cancel());
    unawaited(_autoVerifySub?.cancel());
    unawaited(_manualEntryReadySub?.cancel());
    unawaited(_autoRetrievalTimedOutSub?.cancel());
    _autoVerifyStartedSub = null;
    _autoVerifySub = null;
    _manualEntryReadySub = null;
    _autoRetrievalTimedOutSub = null;
    _isAutoVerifying = false;
  }

  bool _isBackendAutoVerifyResponse(Map<String, dynamic> response) {
    if (response['success'] != true) return false;
    final data = response['data'];
    if (data is! Map) return false;
    return data['sms_sent'] != true;
  }

  Future<Map<String, dynamic>> confirmCode() async {
    if (_isConfirming) {
      return {
        'success': false,
        'error': {'message': AppStrings.current().errVerificationInProgress},
      };
    }

    if (_isAutoVerifying) {
      return {
        'success': false,
        'error': {
          'message': AppStrings.current().errWaitAutoVerify,
        },
      };
    }

    if (!PhoneVerificationService.canSubmitManualCode) {
      return {
        'success': false,
        'error': {
          'message': AppStrings.current().errWaitingForNewCode,
        },
      };
    }

    _isConfirming = true;
    _otpSubmitLocked = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await PhoneVerificationService.verifyCodeAndConfirm(
        phone: apiPhoneNumber,
        smsCode: otpCode,
        email: email,
      );
      if (result['success'] != true) {
        _errorMessage = AuthService.extractErrorMessage(
          result,
          fallback: AppStrings.current().errInvalidCode,
        );
        if (result['firebase_code_consumed'] == true) {
          _clearOtpFields();
          _secondsRemaining = 0;
        } else if (!PhoneVerificationService.canSubmitManualCode) {
          _secondsRemaining = 0;
        }
        _otpSubmitLocked = result['firebase_code_consumed'] == true;
      } else {
        _otpSubmitLocked = false;
      }
      return result;
    } finally {
      _isConfirming = false;
      notifyListeners();
    }
  }

  void _clearOtpFields() {
    for (final controller in digitControllers) {
      controller.clear();
    }
    focusNodes.first.requestFocus();
  }

  Future<Map<String, dynamic>> resendCode() async {
    if (!canResend) {
      return {
        'success': false,
        'error': {'message': AppStrings.current().errWaitBeforeResend},
      };
    }

    for (final controller in digitControllers) {
      controller.clear();
    }
    focusNodes.first.requestFocus();
    return sendCode(forceResend: true);
  }

  void _startTimer() {
    _secondsRemaining = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        notifyListeners();
        return;
      }
      _secondsRemaining--;
      notifyListeners();
    });
    notifyListeners();
  }

  void onDigitChanged(int index, String value) {
    if (value.length > 1) {
      fillOtp(value);
      return;
    }

    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    }
    notifyListeners();
  }

  void fillOtp(String rawDigits) {
    final digits = rawDigits.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < digitControllers.length; i++) {
      digitControllers[i].text = i < digits.length ? digits[i] : '';
    }
    if (digits.isNotEmpty) {
      focusNodes[digits.length.clamp(0, 5)].requestFocus();
    }
    notifyListeners();
  }

  bool get hasCompleteOtp => otpCode.length == 6;

  void onDigitDeleted(int index) {
    if (digitControllers[index].text.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
      digitControllers[index - 1].clear();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancelSessionListeners();
    for (final controller in digitControllers) {
      controller.dispose();
    }
    for (final node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}
