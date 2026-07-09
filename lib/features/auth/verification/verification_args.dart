import '../../../config/api_config.dart';
import '../../../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

class VerificationArgs {
  const VerificationArgs({
    required this.phoneNumber,
    required this.normalizedPhone,
    this.email,
  });

  final String phoneNumber;
  final String normalizedPhone;
  final String? email;

  static const _cacheKeySeparator = '\u{001F}';

  bool get hasValidPhone => normalizedPhone.length >= 11;

  String get cacheKey =>
      '$normalizedPhone$_cacheKeySeparator${email ?? ''}';

  factory VerificationArgs.fromPhone({
    required String phone,
    String? email,
    String countryCode = ApiConfig.defaultCountryCode,
  }) {
    final normalized = AuthService.normalizeDriverPhone(
      phone: phone,
      countryCode: countryCode,
    );
    return VerificationArgs(
      phoneNumber: normalized.isEmpty
          ? formatDriverPhoneDisplay(phone, countryCode: countryCode)
          : formatDriverPhoneDisplay(normalized),
      normalizedPhone: normalized,
      email: email?.trim().isNotEmpty == true ? email!.trim() : null,
    );
  }

  static VerificationArgs fromRoute(Object? arguments) {
    if (arguments is VerificationArgs) return arguments;
    if (arguments is String && arguments.trim().isNotEmpty) {
      return VerificationArgs.fromPhone(phone: arguments);
    }
    return VerificationArgs.fromPhone(phone: '');
  }

  static VerificationArgs? parseCacheKey(String cacheKey) {
    final separator = cacheKey.indexOf(_cacheKeySeparator);
    final normalizedPhone =
        separator >= 0 ? cacheKey.substring(0, separator) : cacheKey;
    final email =
        separator >= 0 ? cacheKey.substring(separator + 1) : '';
    if (normalizedPhone.trim().isEmpty) return null;
    return VerificationArgs.fromPhone(
      phone: normalizedPhone,
      email: email.isEmpty ? null : email,
    );
  }
}
