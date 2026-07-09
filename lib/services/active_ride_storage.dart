import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/home/models/nearby_ride_offer.dart';

class ActiveRideStorage {
  ActiveRideStorage._();

  static const _activeRideKey = 'active_ride_offer';

  static Future<void> save(NearbyRideOffer offer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeRideKey, json.encode(offer.toJson()));
  }

  static Future<NearbyRideOffer?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeRideKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return NearbyRideOffer.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeRideKey);
  }
}
