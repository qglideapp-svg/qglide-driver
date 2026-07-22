import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideStop {
  const RideStop({
    required this.lat,
    required this.lng,
    required this.address,
  });

  final double lat;
  final double lng;
  final String address;

  LatLng get latLng => LatLng(lat, lng);

  String get key =>
      '${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}_$address';

  static RideStop? fromMap(Map<String, dynamic> map) {
    final lat = _readDouble(map['lat']);
    final lng = _readDouble(map['lng']);
    final address = map['address']?.toString().trim();
    if (lat == null || lng == null || address == null || address.isEmpty) {
      return null;
    }

    return RideStop(lat: lat, lng: lng, address: address);
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      'address': address,
    };
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class RiderStopNotification {
  const RiderStopNotification({
    required this.stops,
    this.updatedFare,
  });

  final List<RideStop> stops;
  final double? updatedFare;

  String get primaryAddress =>
      stops.isEmpty ? '--' : stops.first.address;

  String? get updatedFareDisplay {
    final fare = updatedFare;
    if (fare == null) return null;
    if (fare == fare.roundToDouble()) {
      return 'QAR ${fare.round()}';
    }
    return 'QAR ${fare.toStringAsFixed(1)}';
  }
}

class AddedStopArrivalNotification {
  const AddedStopArrivalNotification({
    required this.stop,
    required this.finalDestination,
    this.finalDestinationLatLng,
  });

  final RideStop stop;
  final String finalDestination;
  final LatLng? finalDestinationLatLng;
}

class NearbyRideOffer {
  const NearbyRideOffer({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.pickupEtaMinutes,
    this.pickupEstimatedArrivalTime,
    this.durationMinutes,
    this.estimatedFare,
    this.distanceKm,
    this.riderName,
    this.riderRating,
    this.riderPhotoUrl,
    this.riderPhone,
    this.pickupLatLng,
    this.dropoffLatLng,
    this.hasPendingDropoffChange = false,
    this.stops = const [],
    this.requestedDropoffAddress,
    this.proposedDropoffAddress,
    this.requestedFare,
    this.requestedDropoffLatLng,
  });

  final String id;
  final String status;
  final String pickupAddress;
  final String dropoffAddress;
  final int? pickupEtaMinutes;
  final DateTime? pickupEstimatedArrivalTime;
  final int? durationMinutes;
  final double? estimatedFare;
  final double? distanceKm;
  final String? riderName;
  final double? riderRating;
  final String? riderPhotoUrl;
  final String? riderPhone;
  final LatLng? pickupLatLng;
  final LatLng? dropoffLatLng;
  final bool hasPendingDropoffChange;
  final List<RideStop> stops;
  final String? requestedDropoffAddress;
  final String? proposedDropoffAddress;
  final double? requestedFare;
  final LatLng? requestedDropoffLatLng;

  bool get hasRiderStopRequest => hasPendingDropoffChange || stops.isNotEmpty;

  String? get pendingStopAddress {
    if (stops.isNotEmpty) return stops.first.address;
    for (final value in [proposedDropoffAddress, requestedDropoffAddress]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  String get requestedFareDisplay {
    final fare = requestedFare;
    if (fare == null) return '--';
    if (fare == fare.roundToDouble()) {
      return 'QAR ${fare.round()}';
    }
    return 'QAR ${fare.toStringAsFixed(1)}';
  }

  bool get isPending {
    final normalized = status.toLowerCase();
    return normalized == 'requested' || normalized == 'pending';
  }

  String get pickupTitle => pickupTitleForMinutes(effectivePickupEtaMinutes);

  int? get effectivePickupEtaMinutes {
    final arrival = pickupEstimatedArrivalTime;
    if (arrival != null) {
      return minutesUntilArrival(arrival);
    }
    return pickupEtaMinutes;
  }

  static String pickupTitleForMinutes(int? minutes) {
    if (minutes == null) return 'Pickup nearby';
    return 'Pickup Is ${minutes}mins Away';
  }

  static int? minutesUntilArrival(DateTime arrivalTime) {
    final remaining = arrivalTime.toUtc().difference(DateTime.now().toUtc());
    if (remaining.isNegative) return 0;
    return (remaining.inSeconds / 60).ceil().clamp(0, 999);
  }

  static int? etaMinutesFromDistanceMeters(
    double meters, {
    double speedKmh = 35,
  }) {
    if (meters <= 50) return 0;
    final seconds = meters / (speedKmh * 1000 / 3600);
    return (seconds / 60).ceil().clamp(1, 999);
  }

  static int? resolvePickupEtaMinutes(Map<String, dynamic> ride) {
    final pickupEta = _readInt(ride['pickup_eta_minutes']);
    if (pickupEta != null) return pickupEta;

    final estimatedMinutes = _readInt(ride['estimated_arrival_minutes']);
    if (estimatedMinutes != null) return estimatedMinutes;

    final arrival = parseEstimatedArrivalTime(ride);
    if (arrival != null) return minutesUntilArrival(arrival);
    return null;
  }

  static DateTime? parseEstimatedArrivalTime(Map<String, dynamic> ride) {
    final raw = ride['estimated_arrival_time'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  String get durationDisplay {
    final minutes = durationMinutes;
    if (minutes == null) return '--';
    return '${minutes}mins';
  }

  String get fareDisplay {
    final fare = estimatedFare;
    if (fare == null) return '--';
    if (fare == fare.roundToDouble()) {
      return 'QAR ${fare.round()}';
    }
    return 'QAR ${fare.toStringAsFixed(1)}';
  }

  String get distanceDisplay {
    final distance = distanceKm;
    if (distance == null) return '--';
    if (distance == distance.roundToDouble()) {
      return '${distance.round()}km';
    }
    return '${distance.toStringAsFixed(1)}km';
  }

  static NearbyRideOffer? fromMap(Map<String, dynamic> ride) {
    final id = ride['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final rider = ride['rider'];
    final riderMap = rider is Map<String, dynamic> ? rider : null;

    return NearbyRideOffer(
      id: id,
      status: ride['status']?.toString() ?? 'requested',
      pickupAddress: ride['pickup_address']?.toString() ?? '--',
      dropoffAddress: ride['dropoff_address']?.toString() ?? '--',
      pickupEtaMinutes: resolvePickupEtaMinutes(ride),
      pickupEstimatedArrivalTime: parseEstimatedArrivalTime(ride),
      durationMinutes: _readInt(ride['duration_minutes']),
      estimatedFare: _readDouble(ride['estimated_fare']),
      distanceKm: _readDouble(ride['distance_km']),
      riderName: riderMap?['name']?.toString() ?? ride['rider_name']?.toString(),
      riderRating: _readDouble(riderMap?['rating']),
      riderPhotoUrl: _readPhotoUrl(ride, riderMap) ??
          ride['rider_photo_url']?.toString(),
      riderPhone: _readRiderPhone(ride, riderMap),
      pickupLatLng: _parsePickupLocation(ride),
      dropoffLatLng: _parseDropoffLocation(ride),
      hasPendingDropoffChange: _readBool(ride['pending_dropoff_change']) ||
          _readBool(ride['dropoff_change_requested']),
      requestedDropoffAddress:
          _readOptionalString(ride['requested_dropoff_address']),
      proposedDropoffAddress:
          _readOptionalString(ride['proposed_dropoff_address']),
      requestedFare: _readDouble(ride['requested_fare']),
      requestedDropoffLatLng:
          _parseRequestedDropoffLocation(ride) ?? _parseFirstStopLocation(ride),
      stops: _parseStops(ride['stops']),
    );
  }

  NearbyRideOffer withRetainedDetailsFrom(NearbyRideOffer? previous) {
    if (previous == null || previous.id != id) return this;

    return NearbyRideOffer(
      id: id,
      status: status,
      pickupAddress: _preferValue(pickupAddress, previous.pickupAddress),
      dropoffAddress: _preferValue(dropoffAddress, previous.dropoffAddress),
      pickupEtaMinutes: pickupEtaMinutes ?? previous.pickupEtaMinutes,
      pickupEstimatedArrivalTime:
          pickupEstimatedArrivalTime ?? previous.pickupEstimatedArrivalTime,
      durationMinutes: durationMinutes ?? previous.durationMinutes,
      estimatedFare: estimatedFare ?? previous.estimatedFare,
      distanceKm: distanceKm ?? previous.distanceKm,
      riderName: riderName ?? previous.riderName,
      riderRating: riderRating ?? previous.riderRating,
      riderPhotoUrl: riderPhotoUrl ?? previous.riderPhotoUrl,
      riderPhone: riderPhone ?? previous.riderPhone,
      pickupLatLng: pickupLatLng ?? previous.pickupLatLng,
      dropoffLatLng: dropoffLatLng ?? previous.dropoffLatLng,
      hasPendingDropoffChange: hasPendingDropoffChange,
      stops: stops.isNotEmpty ? stops : previous.stops,
      requestedDropoffAddress:
          requestedDropoffAddress ?? previous.requestedDropoffAddress,
      proposedDropoffAddress:
          proposedDropoffAddress ?? previous.proposedDropoffAddress,
      requestedFare: requestedFare ?? previous.requestedFare,
      requestedDropoffLatLng:
          requestedDropoffLatLng ?? previous.requestedDropoffLatLng,
    );
  }

  /// Merges a status poll while `status === accepted`, preferring fresh ETA fields.
  NearbyRideOffer withAcceptedStatusPoll(NearbyRideOffer? previous) {
    if (previous == null || previous.id != id) return this;

    final retained = withRetainedDetailsFrom(previous);
    final freshPickupEta = pickupEtaMinutes;
    final freshArrivalTime = pickupEstimatedArrivalTime;

    return NearbyRideOffer(
      id: retained.id,
      status: retained.status,
      pickupAddress: retained.pickupAddress,
      dropoffAddress: retained.dropoffAddress,
      pickupEtaMinutes: freshPickupEta ?? retained.pickupEtaMinutes,
      pickupEstimatedArrivalTime:
          freshArrivalTime ?? retained.pickupEstimatedArrivalTime,
      durationMinutes: retained.durationMinutes,
      estimatedFare: retained.estimatedFare,
      distanceKm: retained.distanceKm,
      riderName: retained.riderName,
      riderRating: retained.riderRating,
      riderPhotoUrl: retained.riderPhotoUrl,
      riderPhone: retained.riderPhone,
      pickupLatLng: retained.pickupLatLng,
      dropoffLatLng: retained.dropoffLatLng,
      hasPendingDropoffChange: retained.hasPendingDropoffChange,
      stops: retained.stops,
      requestedDropoffAddress: retained.requestedDropoffAddress,
      proposedDropoffAddress: retained.proposedDropoffAddress,
      requestedFare: retained.requestedFare,
      requestedDropoffLatLng: retained.requestedDropoffLatLng,
    );
  }

  static String? _readPhotoUrl(
    Map<String, dynamic> ride,
    Map<String, dynamic>? riderMap,
  ) {
    final profileMap = ride['profile'] is Map<String, dynamic>
        ? ride['profile'] as Map<String, dynamic>
        : null;
    final passengerMap = ride['passenger'] is Map<String, dynamic>
        ? ride['passenger'] as Map<String, dynamic>
        : null;

    final candidates = [
      riderMap?['photo'],
      riderMap?['photo_url'],
      riderMap?['avatar_url'],
      riderMap?['avatar'],
      profileMap?['photo'],
      profileMap?['avatar_url'],
      passengerMap?['photo'],
      passengerMap?['avatar_url'],
      ride['rider_photo'],
      ride['rider_photo_url'],
      ride['rider_avatar_url'],
      ride['avatar_url'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }

  static String? _readRiderPhone(
    Map<String, dynamic> ride,
    Map<String, dynamic>? riderMap,
  ) {
    final candidates = [
      riderMap?['phone'],
      riderMap?['phone_number'],
      riderMap?['mobile'],
      ride['rider_phone'],
      ride['rider_phone_number'],
    ];

    for (final candidate in candidates) {
      final value = _readOptionalString(candidate);
      if (value != null) return value;
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    final latLng = pickupLatLng;
    final dropLatLng = dropoffLatLng;

    return {
      'id': id,
      'status': status,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      if (pickupEtaMinutes != null) 'pickup_eta_minutes': pickupEtaMinutes,
      if (pickupEstimatedArrivalTime != null)
        'estimated_arrival_time':
            pickupEstimatedArrivalTime!.toUtc().toIso8601String(),
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (estimatedFare != null) 'estimated_fare': estimatedFare,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (riderName != null) 'rider_name': riderName,
      if (riderRating != null) 'rider_rating': riderRating,
      if (riderPhotoUrl != null) 'rider_photo_url': riderPhotoUrl,
      if (riderPhone != null) 'rider_phone': riderPhone,
      if (latLng != null) ...{
        'pickup_lat': latLng.latitude,
        'pickup_lng': latLng.longitude,
      },
      if (dropLatLng != null) ...{
        'dropoff_lat': dropLatLng.latitude,
        'dropoff_lng': dropLatLng.longitude,
      },
      'pending_dropoff_change': hasPendingDropoffChange,
      'dropoff_change_requested': hasPendingDropoffChange,
      if (requestedDropoffAddress != null)
        'requested_dropoff_address': requestedDropoffAddress,
      if (proposedDropoffAddress != null)
        'proposed_dropoff_address': proposedDropoffAddress,
      if (requestedFare != null) 'requested_fare': requestedFare,
      if (requestedDropoffLatLng != null) ...{
        'requested_dropoff_lat': requestedDropoffLatLng!.latitude,
        'requested_dropoff_lng': requestedDropoffLatLng!.longitude,
      },
      if (stops.isNotEmpty) 'stops': stops.map((s) => s.toJson()).toList(),
    };
  }

  static NearbyRideOffer? fromJson(Map<String, dynamic> json) {
    return fromMap(json);
  }

  static String _preferValue(String value, String fallback) {
    if (value.isNotEmpty && value != '--') return value;
    return fallback;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static String? _readOptionalString(dynamic value) {
    final trimmed = value?.toString().trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static LatLng? _parsePickupLocation(Map<String, dynamic> ride) {
    return _parseLatLng(
      ride,
      latKey: 'pickup_lat',
      lngKey: 'pickup_lng',
      locationKey: 'pickup_location',
    );
  }

  static LatLng? _parseDropoffLocation(Map<String, dynamic> ride) {
    return _parseLatLng(
      ride,
      latKey: 'dropoff_lat',
      lngKey: 'dropoff_lng',
      locationKey: 'dropoff_location',
    );
  }

  static LatLng? _parseRequestedDropoffLocation(Map<String, dynamic> ride) {
    return _parseLatLng(
      ride,
      latKey: 'requested_dropoff_lat',
      lngKey: 'requested_dropoff_lng',
      locationKey: 'requested_dropoff_location',
    ) ??
        _parseLatLng(
          ride,
          latKey: 'proposed_dropoff_lat',
          lngKey: 'proposed_dropoff_lng',
          locationKey: 'proposed_dropoff_location',
        );
  }

  static LatLng? _parseFirstStopLocation(Map<String, dynamic> ride) {
    final stops = _parseStops(ride['stops']);
    if (stops.isEmpty) return null;
    return stops.first.latLng;
  }

  static List<RideStop> _parseStops(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((item) => RideStop.fromMap(Map<String, dynamic>.from(item)))
        .whereType<RideStop>()
        .toList();
  }

  static LatLng? _parseLatLng(
    Map<String, dynamic> ride, {
    required String latKey,
    required String lngKey,
    required String locationKey,
  }) {
    final lat = _readDouble(ride[latKey]);
    final lng = _readDouble(ride[lngKey]);
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }

    final location = ride[locationKey]?.toString() ?? '';
    final match = RegExp(r'\((-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\)')
        .firstMatch(location);
    if (match == null) return null;

    final parsedLat = double.tryParse(match.group(1)!);
    final parsedLng = double.tryParse(match.group(2)!);
    if (parsedLat == null || parsedLng == null) return null;
    return LatLng(parsedLat, parsedLng);
  }
}
