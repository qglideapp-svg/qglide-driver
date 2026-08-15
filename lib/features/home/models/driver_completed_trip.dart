import '../../../config/app_strings.dart';
import 'driver_ride_details.dart';

double _readTripDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class DriverCompletedTrip {
  const DriverCompletedTrip({
    required this.id,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.amount,
    required this.distanceKm,
    this.completedAt,
    this.paymentMethod,
  });

  final String id;
  final String pickupAddress;
  final String dropoffAddress;
  final double amount;
  final double distanceKm;
  final DateTime? completedAt;
  final String? paymentMethod;

  bool get isCashPayment => paymentMethod?.trim().toLowerCase() == 'cash';

  String get locationDisplay {
    final dropoff = AppStrings.current().localizeKnownAddress(dropoffAddress);
    if (dropoff.isNotEmpty) return dropoff;
    final pickup = AppStrings.current().localizeKnownAddress(pickupAddress);
    if (pickup.isEmpty) return AppStrings.current().tripFallback;
    return pickup;
  }

  String get dateTimeDisplay =>
      AppStrings.current().formatCompletedTripDateTime(completedAt);

  String get distanceDisplay =>
      AppStrings.current().formatDistanceKm(distanceKm);

  DriverRideDetails toPreviewDetails() {
    return DriverRideDetails(
      id: id,
      status: 'completed',
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      amount: amount,
      distanceKm: distanceKm,
      completedAt: completedAt,
      paymentMethod: paymentMethod,
    );
  }

  factory DriverCompletedTrip.fromJson(Map<String, dynamic> json) {
    final amount = _readTripDouble(
      json['rider_paid_amount'] ??
          json['actual_fare'] ??
          json['estimated_fare'],
    );

    return DriverCompletedTrip(
      id: json['id']?.toString() ?? '',
      pickupAddress: json['pickup_address']?.toString() ?? '',
      dropoffAddress: json['dropoff_address']?.toString() ?? '',
      amount: amount,
      distanceKm: _readTripDouble(json['distance_km']),
      completedAt: _parseDateTime(json['completed_at']),
      paymentMethod: json['payment_method']?.toString(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }
}

class DriverCompletedTripsResult {
  const DriverCompletedTripsResult({
    required this.trips,
    required this.totalCount,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<DriverCompletedTrip> trips;
  final int totalCount;
  final int limit;
  final int offset;
  final bool hasMore;

  int get currentPage => offset ~/ (limit == 0 ? 1 : limit) + 1;
  int get totalPages {
    if (limit <= 0 || totalCount <= 0) return 1;
    return (totalCount / limit).ceil();
  }

  bool get canGoPrevious => offset > 0;
}
