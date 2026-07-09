import 'package:flutter/foundation.dart';

import '../../../config/app_strings.dart';
import '../../../services/auth_service.dart';

class LoginController extends ChangeNotifier {
  LoginController();

  var _obscurePassword = true;
  var _isLoading = false;
  String? _errorMessage;

  bool get obscurePassword => _obscurePassword;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      _errorMessage = AppStrings.current().errEmailPasswordRequired;
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await AuthService.driverLogin(
      email: trimmedEmail,
      password: password,
    );

    _isLoading = false;
    if (response['success'] == true) {
      _errorMessage = null;
      notifyListeners();
      return response;
    }

    _errorMessage = AuthService.extractErrorMessage(response);
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
    );

    _isLoading = false;
    if (response['success'] == true) {
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

    final response = await AuthService.driverAppleSignIn();

    _isLoading = false;
    if (response['success'] == true) {
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
