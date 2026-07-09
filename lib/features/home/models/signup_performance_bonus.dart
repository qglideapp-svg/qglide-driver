enum SignupBonusStatus {
  active,
  completed,
  paid,
  expired,
  ineligible,
}

class SignupPerformanceBonus {
  const SignupPerformanceBonus({
    required this.ridesCompleted,
    required this.targetRides,
    required this.bonusAmount,
    required this.windowDays,
    required this.daysRemaining,
    required this.status,
    this.expiresAt,
  });

  static const milestoneRides = [5, 10, 15, 20];

  final int ridesCompleted;
  final int targetRides;
  final double bonusAmount;
  final int windowDays;
  final int daysRemaining;
  final SignupBonusStatus status;
  final DateTime? expiresAt;

  double get progress {
    if (targetRides <= 0) return 0;
    return (ridesCompleted / targetRides).clamp(0.0, 1.0);
  }

  int get ridesRemaining =>
      (targetRides - ridesCompleted).clamp(0, targetRides);

  bool get isPaid => status == SignupBonusStatus.paid;
  bool get isExpired => status == SignupBonusStatus.expired;
  bool get hasMetTarget => ridesCompleted >= targetRides;

  static SignupPerformanceBonus? fromIncentiveProgressData(
    Map<String, dynamic> data,
  ) {
    final progress = data['progress'] is Map<String, dynamic>
        ? data['progress'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final config = data['config'] is Map<String, dynamic>
        ? data['config'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final thresholds = data['thresholds'] is Map<String, dynamic>
        ? data['thresholds'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final targetRides = _readInt(
      config['signup_bonus_min_rides'] ??
          thresholds['signup_bonus_min_rides'],
    );
    final windowDays = _readInt(
      config['signup_bonus_window_days'] ??
          thresholds['signup_bonus_window_days'],
    );
    final bonusAmount = _readDouble(config['signup_bonus_qar']);
    final ridesCompleted = _readInt(
      progress['signup_window_completed_rides'] ??
          progress['signup_bonus_completed_rides'],
    ).clamp(0, targetRides);
    var expiresAt = _parseDateTime(progress['signup_window_ends_at']);
    final startsAt = _parseDateTime(progress['signup_window_starts_at']);
    if (expiresAt == null && startsAt != null && windowDays > 0) {
      expiresAt = startsAt.add(Duration(days: windowDays));
    }
    final daysRemaining = _daysRemainingFromEndsAt(expiresAt, windowDays);
    final status = _statusFromProgress(progress, expiresAt: expiresAt);

    return SignupPerformanceBonus(
      ridesCompleted: ridesCompleted,
      targetRides: targetRides,
      bonusAmount: bonusAmount,
      windowDays: windowDays,
      daysRemaining: daysRemaining,
      status: status,
      expiresAt: expiresAt,
    );
  }

  static SignupBonusStatus _statusFromProgress(
    Map<String, dynamic> progress, {
    DateTime? expiresAt,
  }) {
    final claimed = progress['signup_bonus_claimed'] == true;
    final unlocked = progress['signup_bonus_unlocked'] == true;
    if (claimed) return SignupBonusStatus.paid;
    if (unlocked) return SignupBonusStatus.completed;

    final startsAt = _parseDateTime(progress['signup_window_starts_at']);
    final endsAt =
        expiresAt ?? _parseDateTime(progress['signup_window_ends_at']);
    final windowActiveFlag = progress['signup_window_active'] == true;
    final now = DateTime.now().toUtc();

    final enrolledInProgram =
        windowActiveFlag || startsAt != null || endsAt != null;
    if (!enrolledInProgram) {
      return SignupBonusStatus.ineligible;
    }

    final windowStillOpen = windowActiveFlag ||
        (endsAt != null && endsAt.isAfter(now));

    if (windowStillOpen) return SignupBonusStatus.active;
    return SignupBonusStatus.expired;
  }

  static int _daysRemainingFromEndsAt(DateTime? endsAt, int windowDays) {
    if (endsAt == null) return windowDays;

    final now = DateTime.now().toUtc();
    if (!endsAt.isAfter(now)) return 0;

    final hoursLeft = endsAt.difference(now).inHours;
    return (hoursLeft / 24).ceil().clamp(0, windowDays);
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toUtc();
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _readDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
