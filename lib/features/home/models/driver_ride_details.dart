double _readDetailsDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int? _readDetailsInt(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _readDetailsDateTime(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

String formatRideTripDisplayId(String rideId) {
  final cleaned = rideId.replaceAll('-', '').trim();
  if (cleaned.length >= 5) {
    return 'RX-${cleaned.substring(0, 5).toUpperCase()}';
  }
  if (cleaned.isEmpty) return '--';
  return cleaned.toUpperCase();
}

String formatRideDetailsDateTime(DateTime? dateTime) {
  if (dateTime == null) return '--';

  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final weekday = weekdays[dateTime.weekday - 1];
  final month = months[dateTime.month - 1];
  final hour = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;

  return '$weekday, ${dateTime.day} $month ${dateTime.year} '
      '$hour12:$minute $period';
}

String formatRideDetailsAmount(double amount) {
  if (amount <= 0) return '--';
  final rounded = amount.round();
  final text = rounded.toString();
  final buffer = StringBuffer('QAR ');
  for (var i = 0; i < text.length; i++) {
    final positionFromEnd = text.length - i;
    buffer.write(text[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String formatRideDetailsDistance(double distanceKm) {
  if (distanceKm <= 0) return '--';
  final rounded = (distanceKm * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
  return '$text km';
}

String formatRideDetailsDuration(int? durationMinutes) {
  if (durationMinutes == null || durationMinutes <= 0) return '--';
  return '$durationMinutes mins';
}

String formatRideDetailsRating(double? rating) {
  if (rating == null || rating <= 0) return '--';
  final rounded = (rating * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
}

class DriverRideDetails {
  const DriverRideDetails({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.amount,
    required this.distanceKm,
    this.completedAt,
    this.durationMinutes,
    this.riderName,
    this.riderEmail,
    this.riderRating,
  });

  final String id;
  final String status;
  final String pickupAddress;
  final String dropoffAddress;
  final double amount;
  final double distanceKm;
  final DateTime? completedAt;
  final int? durationMinutes;
  final String? riderName;
  final String? riderEmail;
  final double? riderRating;

  String get tripIdDisplay => formatRideTripDisplayId(id);

  String get statusDisplay {
    final normalized = status.toLowerCase();
    if (normalized == 'completed') return 'Completed';
    if (normalized == 'cancelled') return 'Cancelled';
    if (normalized.isEmpty) return '--';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  bool get isCompleted => status.toLowerCase() == 'completed';

  String get dateDisplay => formatRideDetailsDateTime(completedAt);

  String get amountDisplay => formatRideDetailsAmount(amount);

  String get distanceDisplay => formatRideDetailsDistance(distanceKm);

  String get durationDisplay => formatRideDetailsDuration(durationMinutes);

  String get riderNameDisplay {
    final name = riderName?.trim();
    if (name == null || name.isEmpty) return '--';
    return name;
  }

  String get riderEmailDisplay {
    final email = riderEmail?.trim();
    if (email == null || email.isEmpty) return '--';
    return email;
  }

  String get riderRatingDisplay => formatRideDetailsRating(riderRating);

  factory DriverRideDetails.fromRideStatus(
    Map<String, dynamic> ride, {
    double? paidAmount,
  }) {
    final rider = ride['rider'];
    final riderMap = rider is Map<String, dynamic>
        ? rider
        : rider is Map
            ? Map<String, dynamic>.from(rider)
            : null;

    final actualFare = _readDetailsDouble(ride['actual_fare']);
    final estimatedFare = _readDetailsDouble(ride['estimated_fare']);
    final amount = paidAmount != null && paidAmount > 0
        ? paidAmount
        : (actualFare > 0 ? actualFare : estimatedFare);

    return DriverRideDetails(
      id: ride['id']?.toString() ?? '',
      status: ride['status']?.toString() ?? '',
      pickupAddress: ride['pickup_address']?.toString() ?? '',
      dropoffAddress: ride['dropoff_address']?.toString() ?? '',
      amount: amount,
      distanceKm: _readDetailsDouble(ride['distance_km']),
      completedAt: _readDetailsDateTime(ride['completed_at']),
      durationMinutes: _readDetailsInt(ride['duration_minutes']),
      riderName: riderMap?['name']?.toString(),
      riderEmail: riderMap?['email']?.toString(),
      riderRating: riderMap?['rating'] == null
          ? null
          : _readDetailsDouble(riderMap?['rating']),
    );
  }

  factory DriverRideDetails.fromCompleteRidePayload(
    Map<String, dynamic> payload, {
    double? distanceKm,
    int? durationMinutes,
    double? riderRating,
  }) {
    final ride = payload['ride'];
    final rideMap = ride is Map<String, dynamic>
        ? ride
        : ride is Map
            ? Map<String, dynamic>.from(ride)
            : null;
    if (rideMap == null) {
      throw ArgumentError('complete-ride payload is missing ride');
    }

    final rider = rideMap['rider'];
    final riderMap = rider is Map<String, dynamic>
        ? rider
        : rider is Map
            ? Map<String, dynamic>.from(rider)
            : null;

    var amount = _readDetailsDouble(rideMap['actual_fare']);
    if (amount <= 0) {
      final walletPayment = payload['wallet_payment'];
      if (walletPayment is Map<String, dynamic>) {
        amount = _readDetailsDouble(walletPayment['fare_amount']);
      } else if (walletPayment is Map) {
        amount = _readDetailsDouble(
          Map<String, dynamic>.from(walletPayment)['fare_amount'],
        );
      }
    }
    if (amount <= 0) {
      final driverEarnings = payload['driver_earnings'];
      if (driverEarnings is Map<String, dynamic>) {
        amount = _readDetailsDouble(driverEarnings['gross_amount']);
      } else if (driverEarnings is Map) {
        amount = _readDetailsDouble(
          Map<String, dynamic>.from(driverEarnings)['gross_amount'],
        );
      }
    }
    if (amount <= 0) {
      amount = _readDetailsDouble(rideMap['estimated_fare']);
    }

    return DriverRideDetails(
      id: rideMap['id']?.toString() ?? '',
      status: rideMap['status']?.toString() ?? 'completed',
      pickupAddress: rideMap['pickup_address']?.toString() ?? '',
      dropoffAddress: rideMap['dropoff_address']?.toString() ?? '',
      amount: amount,
      distanceKm: distanceKm ?? 0,
      completedAt: _readDetailsDateTime(rideMap['completed_at']),
      durationMinutes: durationMinutes,
      riderName: riderMap?['name']?.toString(),
      riderEmail: riderMap?['email']?.toString(),
      riderRating: riderRating,
    );
  }
}
