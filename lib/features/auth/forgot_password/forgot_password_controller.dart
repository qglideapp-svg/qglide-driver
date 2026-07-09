import 'package:flutter/foundation.dart';

import '../../../config/app_strings.dart';
import '../../../services/auth_service.dart';

class ForgotPasswordController extends ChangeNotifier {
  var _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<String?> sendResetLink({required String email}) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      _errorMessage = AppStrings.current().errEnterEmail;
      notifyListeners();
      return null;
    }

    if (!trimmedEmail.contains('@')) {
      _errorMessage = AppStrings.current().errValidEmail;
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await AuthService.forgotPassword(email: trimmedEmail);

    _isLoading = false;
    if (response['success'] == true) {
      _errorMessage = null;
      notifyListeners();
      return AuthService.extractSuccessMessage(
        response,
        fallback: AppStrings.current().errPasswordResetSent,
      );
    }

    _errorMessage = AuthService.extractErrorMessage(
      response,
      fallback: AppStrings.current().errPasswordResetFailed,
    );
    notifyListeners();
    return null;
  }
}
