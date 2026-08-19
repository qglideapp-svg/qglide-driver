import 'package:flutter/foundation.dart';

import '../../../config/api_config.dart';
import '../../../config/app_strings.dart';
import '../../../services/auth_service.dart';
import 'password_requirements.dart';

class SignupController extends ChangeNotifier {
  var _obscurePassword = true;
  var _obscureConfirmPassword = true;
  var _isLoading = false;
  var _isOAuthSignupPending = false;
  String? _errorMessage;

  bool get obscurePassword => _obscurePassword;
  bool get obscureConfirmPassword => _obscureConfirmPassword;
  bool get isLoading => _isLoading;
  bool get isOAuthSignupPending => _isOAuthSignupPending;
  String? get errorMessage => _errorMessage;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _obscureConfirmPassword = !_obscureConfirmPassword;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> signUp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
    String? referralCode,
    String? partnerCode,
  }) async {
    final trimmedName = fullName.trim();
    final trimmedEmail = email.trim();
    final trimmedPhone = phoneNumber.trim();

    if (trimmedName.isEmpty ||
        trimmedEmail.isEmpty ||
        trimmedPhone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _errorMessage = AppStrings.current().fillRequiredFields;
      notifyListeners();
      return null;
    }

    if (password != confirmPassword) {
      _errorMessage = AppStrings.current().passwordsDoNotMatch;
      notifyListeners();
      return null;
    }

    if (!PasswordRequirements.evaluate(password).isMet) {
      _errorMessage = AppStrings.current().passwordRequirements;
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await AuthService.driverSignup(
      fullName: trimmedName,
      email: trimmedEmail,
      phoneNumber: trimmedPhone,
      password: password,
      confirmPassword: confirmPassword,
      referralCode: referralCode,
      partnerCode: partnerCode,
      countryCode: ApiConfig.defaultCountryCode,
    );

    _isLoading = false;
    if (response['success'] == true) {
      _errorMessage = null;
      notifyListeners();
      return response;
    }

    _errorMessage = AuthService.extractErrorMessage(
      response,
      fallback: AppStrings.current().errSignUp,
    );
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>?> completeOAuthSignup({
    required String fullName,
    required String email,
    required String phoneNumber,
    String? referralCode,
    String? partnerCode,
  }) async {
    if (!_isOAuthSignupPending) return null;

    final trimmedName = fullName.trim();
    final trimmedEmail = email.trim();
    final trimmedPhone = phoneNumber.trim();

    if (trimmedName.isEmpty ||
        trimmedEmail.isEmpty ||
        trimmedPhone.isEmpty) {
      _errorMessage = AppStrings.current().fillRequiredFields;
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await AuthService.completeOAuthDriverSignup(
      fullName: trimmedName,
      email: trimmedEmail,
      phoneNumber: trimmedPhone,
      referralCode: referralCode,
      partnerCode: partnerCode,
      countryCode: ApiConfig.defaultCountryCode,
    );

    _isLoading = false;
    if (response['success'] == true) {
      _isOAuthSignupPending = false;
      _errorMessage = null;
      notifyListeners();
      return response;
    }

    _errorMessage = AuthService.extractErrorMessage(
      response,
      fallback: AppStrings.current().errCreateAccount,
    );
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>?> signInWithGoogle({
    VoidCallback? onAccountSelected,
  }) async {
    if (_isLoading) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await AuthService.driverGoogleSignIn(
      onAccountSelected: onAccountSelected,
      completeRegistration: false,
    );

    _isLoading = false;
    if (response['success'] == true) {
      _isOAuthSignupPending = true;
      _errorMessage = null;
      notifyListeners();
      return response;
    }

    if (response['cancelled'] == true) {
      _errorMessage = null;
      notifyListeners();
      return null;
    }

    _errorMessage = AuthService.extractErrorMessage(
      response,
      fallback: AppStrings.current().errGoogleSignIn,
    );
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>?> signInWithApple() async {
    if (_isLoading) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await AuthService.driverAppleSignIn(
      completeRegistration: false,
    );

    _isLoading = false;
    if (response['success'] == true) {
      _isOAuthSignupPending = true;
      _errorMessage = null;
      notifyListeners();
      return response;
    }

    if (response['cancelled'] == true) {
      _errorMessage = null;
      notifyListeners();
      return null;
    }

    _errorMessage = AuthService.extractErrorMessage(
      response,
      fallback: AppStrings.current().errAppleSignIn,
    );
    notifyListeners();
    return null;
  }
}
