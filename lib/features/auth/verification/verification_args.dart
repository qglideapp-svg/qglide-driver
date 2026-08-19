import '../../../config/api_config.dart';
import '../../../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

class VerificationArgs {
  const VerificationArgs({
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
  /// When true, always request a new SMS instead of reusing a persisted session.
  final bool requireFreshSms;

  static const _cacheKeySeparator = '\u{001F}';

  bool get hasValidPhone => normalizedPhone.length >= 11;

  String get cacheKey =>
      '$normalizedPhone$_cacheKeySeparator${email ?? ''}$_cacheKeySeparator${firebasePhoneE164 ?? ''}$_cacheKeySeparator$requireFreshSms';

  factory VerificationArgs.fromPhone({
    required String phone,
    String? email,
    String? firebasePhoneE164,
    bool requireFreshSms = false,
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
      firebasePhoneE164: _normalizeFirebasePhoneE164(firebasePhoneE164),
      requireFreshSms: requireFreshSms,
    );
  }

  static String? _normalizeFirebasePhoneE164(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.startsWith('+')) return trimmed;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return '+$digits';
  }

  static VerificationArgs fromRoute(Object? arguments) {
    if (arguments is VerificationArgs) return arguments;
    if (arguments is String && arguments.trim().isNotEmpty) {
      return VerificationArgs.fromPhone(phone: arguments);
    }
    return VerificationArgs.fromPhone(phone: '');
  }

  static VerificationArgs? parseCacheKey(String cacheKey) {
    final parts = cacheKey.split(_cacheKeySeparator);
    final normalizedPhone = parts.isNotEmpty ? parts[0] : '';
    final email = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    final firebasePhoneE164 =
        parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
    final requireFreshSms =
        parts.length > 3 && parts[3].toLowerCase() == 'true';
    if (normalizedPhone.trim().isEmpty) return null;
    return VerificationArgs.fromPhone(
      phone: normalizedPhone,
      email: email,
      firebasePhoneE164: firebasePhoneE164,
      requireFreshSms: requireFreshSms,
    );
  }
}
