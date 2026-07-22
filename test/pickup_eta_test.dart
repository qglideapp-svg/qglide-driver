import 'package:driver/features/home/models/nearby_ride_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('minutesUntilArrival', () {
    test('returns 0 when arrival time is in the past', () {
      final arrival = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      expect(NearbyRideOffer.minutesUntilArrival(arrival), 0);
    });

    test('rounds up partial minutes', () {
      final arrival = DateTime.now().toUtc().add(const Duration(seconds: 90));
      expect(NearbyRideOffer.minutesUntilArrival(arrival), 2);
    });

    test('returns 1 for exactly one minute remaining', () {
      final arrival = DateTime.now().toUtc().add(const Duration(seconds: 60));
      expect(NearbyRideOffer.minutesUntilArrival(arrival), 1);
    });
  });

  group('etaMinutesFromDistanceMeters', () {
    test('returns 0 when within nearby threshold', () {
      expect(NearbyRideOffer.etaMinutesFromDistanceMeters(50), 0);
      expect(NearbyRideOffer.etaMinutesFromDistanceMeters(10), 0);
    });

    test('returns at least 1 minute beyond nearby threshold', () {
      expect(NearbyRideOffer.etaMinutesFromDistanceMeters(51), 1);
    });

    test('estimates longer travel for longer distances', () {
      final shortTrip = NearbyRideOffer.etaMinutesFromDistanceMeters(1000);
      final longTrip = NearbyRideOffer.etaMinutesFromDistanceMeters(7000);
      expect(shortTrip, isNotNull);
      expect(longTrip, isNotNull);
      expect(longTrip!, greaterThan(shortTrip!));
    });
  });

  group('pickupTitleForMinutes', () {
    test('formats pickup title', () {
      expect(
        NearbyRideOffer.pickupTitleForMinutes(5),
        'Pickup Is 5mins Away',
      );
      expect(NearbyRideOffer.pickupTitleForMinutes(null), 'Pickup nearby');
    });
  });
}
