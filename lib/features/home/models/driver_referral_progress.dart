class DriverReferralProgramInfo {
  const DriverReferralProgramInfo({
    required this.title,
    required this.description,
    required this.minRides,
    required this.bountyQar,
    required this.windowDays,
  });

  final String title;
  final String description;
  final int minRides;
  final double bountyQar;
  final int windowDays;

  factory DriverReferralProgramInfo.fromJson(Map<String, dynamic> json) {
    return DriverReferralProgramInfo(
      title: json['title']?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      minRides: _readInt(json['min_rides']),
      bountyQar: _readDouble(json['bounty_qar']),
      windowDays: _readInt(json['window_days']),
    );
  }
}

class ReferredDriverProgress {
  const ReferredDriverProgress({
    required this.referralId,
    required this.referredDriverId,
    required this.referredName,
    required this.completedRides,
    required this.minRidesRequired,
    required this.ridesRemaining,
    required this.qualified,
    required this.bountyWindowActive,
    this.bountyWindowEndsAt,
    this.referredAt,
    this.qualifiedAt,
    this.payout,
  });

  final String referralId;
  final String referredDriverId;
  final String referredName;
  final int completedRides;
  final int minRidesRequired;
  final int ridesRemaining;
  final bool qualified;
  final bool bountyWindowActive;
  final DateTime? bountyWindowEndsAt;
  final DateTime? referredAt;
  final DateTime? qualifiedAt;
  final Map<String, dynamic>? payout;

  double get progressFraction {
    if (minRidesRequired <= 0) return 0;
    return (completedRides / minRidesRequired).clamp(0.0, 1.0);
  }

  bool get isPaid => payout != null && payout!.isNotEmpty;

  factory ReferredDriverProgress.fromJson(Map<String, dynamic> json) {
    return ReferredDriverProgress(
      referralId: json['referral_id']?.toString() ?? '',
      referredDriverId: json['referred_driver_id']?.toString() ?? '',
      referredName: json['referred_name']?.toString().trim() ?? '',
      completedRides: _readInt(json['completed_rides']),
      minRidesRequired: _readInt(json['min_rides_required']),
      ridesRemaining: _readInt(json['rides_remaining']),
      qualified: json['qualified'] == true,
      bountyWindowActive: json['bounty_window_active'] == true,
      bountyWindowEndsAt: _readDateTime(json['bounty_window_ends_at']),
      referredAt: _readDateTime(json['referred_at']),
      qualifiedAt: _readDateTime(json['qualified_at']),
      payout: json['payout'] is Map<String, dynamic>
          ? json['payout'] as Map<String, dynamic>
          : null,
    );
  }
}

class DriverReferralProgress {
  const DriverReferralProgress({
    this.program,
    required this.referralCode,
    required this.referralActive,
    required this.totalReferrals,
    required this.qualifiedCount,
    required this.paidCommissionCount,
    required this.totalCommissionEarnedQar,
    required this.referredDrivers,
  });

  final DriverReferralProgramInfo? program;
  final String referralCode;
  final bool referralActive;
  final int totalReferrals;
  final int qualifiedCount;
  final int paidCommissionCount;
  final double totalCommissionEarnedQar;
  final List<ReferredDriverProgress> referredDrivers;

  double get bountyQar => program?.bountyQar ?? 0;

  int get minRides => program?.minRides ?? 0;

  int get windowDays => program?.windowDays ?? 0;

  factory DriverReferralProgress.fromReferralProgressData(
    Map<String, dynamic> data,
  ) {
    final programJson = data['program'];
    final referredDriversJson = data['referred_drivers'];

    return DriverReferralProgress(
      program: programJson is Map<String, dynamic>
          ? DriverReferralProgramInfo.fromJson(programJson)
          : null,
      referralCode: data['referral_code']?.toString().trim() ?? '',
      referralActive: data['referral_active'] == true,
      totalReferrals: _readInt(data['total_referrals']),
      qualifiedCount: _readInt(data['qualified_count']),
      paidCommissionCount: _readInt(data['paid_commission_count']),
      totalCommissionEarnedQar: _readDouble(data['total_commission_earned_qar']),
      referredDrivers: referredDriversJson is List
          ? referredDriversJson
              .whereType<Map>()
              .map(
                (item) => ReferredDriverProgress.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _readDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _readDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
