/// Pickup wait-time tracking after the driver marks arrival at the rider.
class PickupWaitTimeSnapshot {
  const PickupWaitTimeSnapshot({
    this.arrivedAt,
    this.graceMinutes = 3,
    this.feePerMinute,
    this.serverWaitSeconds,
    this.serverWaitMinutesElapsed,
    this.serverWaitMinutesBilled,
    this.waitBillingActive,
    this.estimatedWaitChargeQar,
    this.serverSyncedAt,
  });

  final DateTime? arrivedAt;
  final int graceMinutes;
  final double? feePerMinute;
  final int? serverWaitSeconds;
  final double? serverWaitMinutesElapsed;
  final double? serverWaitMinutesBilled;
  final bool? waitBillingActive;
  final double? estimatedWaitChargeQar;
  final DateTime? serverSyncedAt;

  bool get hasServerWaitTime =>
      serverWaitMinutesElapsed != null && serverSyncedAt != null;

  bool get isTracking =>
      arrivedAt != null || hasServerWaitTime || (serverWaitSeconds ?? 0) > 0;

  Duration get elapsed {
    if (hasServerWaitTime) {
      final extrapolatedMinutes = _extrapolatedElapsedMinutes();
      return _minutesToDuration(extrapolatedMinutes);
    }
    if (arrivedAt != null) {
      final now = DateTime.now().toUtc();
      final diff = now.difference(arrivedAt!);
      return diff.isNegative ? Duration.zero : diff;
    }
    if (serverWaitSeconds != null && serverWaitSeconds! >= 0) {
      return Duration(seconds: serverWaitSeconds!);
    }
    return Duration.zero;
  }

  Duration get graceDuration => Duration(minutes: graceMinutes);

  bool get isInGracePeriod {
    if (waitBillingActive == false) return true;
    if (waitBillingActive == true) return false;
    return elapsed < graceDuration;
  }

  Duration get graceRemaining {
    final remaining = graceDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration get billableWait {
    if (hasServerWaitTime) {
      if (waitBillingActive == false) return Duration.zero;
      if (serverWaitMinutesBilled != null) {
        final extrapolatedMinutes = _extrapolatedBilledMinutes();
        return _minutesToDuration(extrapolatedMinutes);
      }
    }
    final over = elapsed - graceDuration;
    return over.isNegative ? Duration.zero : over;
  }

  double? get estimatedChargeQar {
    if (estimatedWaitChargeQar == null) return null;
    if (!hasServerWaitTime || waitBillingActive != true) {
      return estimatedWaitChargeQar;
    }
    final billedMinutes = _extrapolatedBilledMinutes();
    final rate = feePerMinute;
    if (rate != null && rate > 0) {
      return billedMinutes * rate;
    }
    return estimatedWaitChargeQar;
  }

  String formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Keeps the later arrival instant so API resync cannot jump the wait clock forward.
  static DateTime? mergeArrivalAnchors(DateTime? local, DateTime? server) {
    if (local == null) return server;
    if (server == null) return local;
    return local.isAfter(server) ? local : server;
  }

  PickupWaitTimeSnapshot copyWith({
    DateTime? arrivedAt,
    int? graceMinutes,
    double? feePerMinute,
    int? serverWaitSeconds,
    double? serverWaitMinutesElapsed,
    double? serverWaitMinutesBilled,
    bool? waitBillingActive,
    double? estimatedWaitChargeQar,
    DateTime? serverSyncedAt,
  }) {
    return PickupWaitTimeSnapshot(
      arrivedAt: arrivedAt ?? this.arrivedAt,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      feePerMinute: feePerMinute ?? this.feePerMinute,
      serverWaitSeconds: serverWaitSeconds ?? this.serverWaitSeconds,
      serverWaitMinutesElapsed:
          serverWaitMinutesElapsed ?? this.serverWaitMinutesElapsed,
      serverWaitMinutesBilled:
          serverWaitMinutesBilled ?? this.serverWaitMinutesBilled,
      waitBillingActive: waitBillingActive ?? this.waitBillingActive,
      estimatedWaitChargeQar:
          estimatedWaitChargeQar ?? this.estimatedWaitChargeQar,
      serverSyncedAt: serverSyncedAt ?? this.serverSyncedAt,
    );
  }

  double _extrapolatedElapsedMinutes() {
    final base = serverWaitMinutesElapsed ?? 0;
    final syncedAt = serverSyncedAt;
    if (syncedAt == null) return base;
    final sinceSync = DateTime.now().toUtc().difference(syncedAt);
    return base + sinceSync.inMilliseconds / 60000.0;
  }

  double _extrapolatedBilledMinutes() {
    final base = serverWaitMinutesBilled ?? 0;
    final syncedAt = serverSyncedAt;
    if (syncedAt == null) return base;
    final sinceSync = DateTime.now().toUtc().difference(syncedAt);
    return base + sinceSync.inMilliseconds / 60000.0;
  }

  Duration _minutesToDuration(double minutes) {
    if (minutes <= 0) return Duration.zero;
    return Duration(milliseconds: (minutes * 60000).round());
  }
}

class PickupWaitTimeParser {
  PickupWaitTimeParser._();

  static PickupWaitTimeSnapshot fromRideMap(Map<String, dynamic>? ride) {
    if (ride == null) {
      return const PickupWaitTimeSnapshot();
    }

    final waitTime = ride['wait_time'];
    if (waitTime is Map) {
      return _fromWaitTimeMap(Map<String, dynamic>.from(waitTime));
    }

    final arrivedAt = _parseDateTime(
      ride['driver_arrived_at'] ??
          ride['arrived_at'] ??
          ride['arrived_at_pickup'] ??
          ride['pickup_arrived_at'] ??
          ride['driver_arrived_at_pickup'],
    );

    final graceMinutes = _readInt(
          ride['grace_period_minutes'] ??
              ride['free_wait_minutes'] ??
              ride['wait_grace_minutes'],
        ) ??
        3;

    final feePerMinute = _readDouble(
      ride['wait_fee_per_minute'] ??
          ride['waiting_fee_rate'] ??
          ride['wait_rate_per_minute'] ??
          ride['wait_cost_per_minute'],
    );

    final serverWaitSeconds = _readInt(
      ride['wait_time_seconds'] ??
          ride['waiting_seconds'] ??
          ride['pickup_wait_seconds'],
    );

    return PickupWaitTimeSnapshot(
      arrivedAt: arrivedAt,
      graceMinutes: graceMinutes.clamp(0, 60),
      feePerMinute: feePerMinute,
      serverWaitSeconds: serverWaitSeconds,
    );
  }

  static PickupWaitTimeSnapshot _fromWaitTimeMap(
    Map<String, dynamic> waitTime,
  ) {
    final arrivedAt = _parseDateTime(waitTime['arrived_at_pickup']);
    final graceMinutes = _readInt(waitTime['wait_grace_minutes']) ?? 3;
    final feePerMinute = _readDouble(waitTime['wait_cost_per_minute']);
    final waitMinutesElapsed = _readDouble(waitTime['wait_minutes_elapsed']);
    final waitMinutesBilled = _readDouble(waitTime['wait_minutes_billed']);
    final waitBillingActive = _readBool(waitTime['wait_billing_active']);
    final estimatedCharge = _readDouble(waitTime['estimated_wait_charge_qar']);

    return PickupWaitTimeSnapshot(
      arrivedAt: arrivedAt,
      graceMinutes: graceMinutes.clamp(0, 60),
      feePerMinute: feePerMinute,
      serverWaitMinutesElapsed: waitMinutesElapsed,
      serverWaitMinutesBilled: waitMinutesBilled,
      waitBillingActive: waitBillingActive,
      estimatedWaitChargeQar: estimatedCharge,
      serverSyncedAt: DateTime.now().toUtc(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toUtc();
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }
}
