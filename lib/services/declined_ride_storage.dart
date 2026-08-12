import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers ride ids the driver declined so stale launch payloads and nearby
/// polling cannot flash the request panel again after restart.
class DeclinedRideStorage {
  DeclinedRideStorage._();

  static const _storageKey = 'declined_ride_requests';
  static const _retention = Duration(hours: 24);
  static const _maxEntries = 32;

  static Future<void> remember(String rideId) async {
    final normalized = rideId.trim();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final entries = _readEntries(prefs);
    entries.removeWhere((entry) => entry.id == normalized);
    entries.insert(0, _DeclinedRideEntry(id: normalized, declinedAtMs: now));

    final cutoff = now - _retention.inMilliseconds;
    entries.removeWhere((entry) => entry.declinedAtMs < cutoff);
    while (entries.length > _maxEntries) {
      entries.removeLast();
    }

    await prefs.setString(
      _storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  static Future<bool> contains(String rideId) async {
    final normalized = rideId.trim();
    if (normalized.isEmpty) return false;
    final active = await loadActiveIds();
    return active.contains(normalized);
  }

  static Future<Set<String>> loadActiveIds() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final cutoff = now - _retention.inMilliseconds;
    final entries =
        _readEntries(prefs).where((entry) => entry.declinedAtMs >= cutoff);

    final ids = entries.map((entry) => entry.id).toSet();
    if (ids.length != _readEntries(prefs).length) {
      await prefs.setString(
        _storageKey,
        jsonEncode(
          entries.map((entry) => entry.toJson()).toList(),
        ),
      );
    }
    return ids;
  }

  static List<_DeclinedRideEntry> _readEntries(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((entry) => _DeclinedRideEntry.fromJson(entry))
          .whereType<_DeclinedRideEntry>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class _DeclinedRideEntry {
  const _DeclinedRideEntry({
    required this.id,
    required this.declinedAtMs,
  });

  final String id;
  final int declinedAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'declined_at_ms': declinedAtMs,
      };

  static _DeclinedRideEntry? fromJson(Map<dynamic, dynamic> json) {
    final id = json['id']?.toString().trim();
    final declinedAtMs = json['declined_at_ms'];
    if (id == null || id.isEmpty || declinedAtMs is! num) return null;
    return _DeclinedRideEntry(
      id: id,
      declinedAtMs: declinedAtMs.round(),
    );
  }
}
