import 'driver_referral_program_terms.dart';

class DriverReferralProgress {
  const DriverReferralProgress({
    required this.referralCode,
    required this.referralActive,
    required this.qualifiedCount,
    required this.paidCommissionCount,
    required this.bountyQar,
    required this.minRides,
    required this.windowDays,
  });

  final String referralCode;
  final bool referralActive;
  final int qualifiedCount;
  final int paidCommissionCount;
  final double bountyQar;
  final int minRides;
  final int windowDays;

  static DriverReferralProgress? fromIncentiveProgressData(
    Map<String, dynamic> data,
  ) {
    final referrals = data['referrals'] is Map<String, dynamic>
        ? data['referrals'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final thresholds = data['thresholds'] is Map<String, dynamic>
        ? data['thresholds'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final config = data['config'] is Map<String, dynamic>
        ? data['config'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final referralCode = (data['referral_code'] ?? '').toString().trim();
    if (referralCode.isEmpty &&
        referrals.isEmpty &&
        thresholds.isEmpty &&
        config.isEmpty) {
      return null;
    }

    return DriverReferralProgress(
      referralCode: referralCode,
      referralActive: data['referral_active'] == true,
      qualifiedCount: _readInt(referrals['qualified_count']),
      paidCommissionCount: _readInt(referrals['paid_commission_count']),
      bountyQar: _readDouble(
        referrals['bounty_qar'] ??
            thresholds['referral_commission_qar'] ??
            config['referral_commission_qar'],
        fallback: DriverReferralProgramTerms.bountyQar,
      ),
      minRides: _readInt(
        referrals['min_rides'] ??
            thresholds['referral_min_rides'] ??
            config['referral_min_rides'],
        fallback: DriverReferralProgramTerms.minRides,
      ),
      windowDays: _readInt(
        referrals['window_days'] ??
            thresholds['referral_bounty_window_days'] ??
            config['referral_bounty_window_days'],
        fallback: DriverReferralProgramTerms.windowDays,
      ),
    );
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _readDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double get totalBalanceCredited =>
      paidCommissionCount * DriverReferralProgramTerms.bountyQar;
}
