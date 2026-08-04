import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_constants.dart';

class DirectionsService {
  DirectionsService._();

  static Future<List<LatLng>> fetchDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    void Function(List<LatLng> overviewPoints)? onOverviewReady,
  }) async {
    final route = await _fetchRouteJson(origin: origin, destination: destination);
    if (route == null) return const [];

    final overview = _overviewPointsFromRoute(route);
    if (overview.length >= 2) {
      onOverviewReady?.call(overview);
    }

    final detailedPoints = _decodeRouteSteps(route);
    if (detailedPoints.length >= 2) {
      return detailedPoints;
    }

    return overview.length >= 2 ? overview : const [];
  }

  static Future<Map<String, dynamic>?> _fetchRouteJson({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/directions/json',
        {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'mode': 'driving',
          'key': AppConstants.googleMapsApiKey,
        },
      );

      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status']?.toString() != 'OK') return null;

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first;
      if (route is Map<String, dynamic>) return route;
      return Map<String, dynamic>.from(route as Map);
    } catch (_) {
      return null;
    }
  }

  static List<LatLng> _overviewPointsFromRoute(Map<String, dynamic> route) {
    final overview = route['overview_polyline'] as Map<String, dynamic>?;
    final encoded = overview?['points']?.toString();
    if (encoded == null || encoded.isEmpty) return const [];

    final overviewPoints = _decodePolyline(encoded);
    return overviewPoints.length >= 2 ? overviewPoints : const [];
  }

  static List<LatLng> _decodeRouteSteps(Map<String, dynamic> route) {
    final points = <LatLng>[];
    final legs = route['legs'] as List<dynamic>?;
    if (legs == null) return points;

    for (final leg in legs) {
      if (leg is! Map) continue;
      final legMap = leg is Map<String, dynamic>
          ? leg
          : Map<String, dynamic>.from(leg);
      final steps = legMap['steps'] as List<dynamic>?;
      if (steps == null) continue;

      for (final step in steps) {
        if (step is! Map) continue;
        final stepMap = step is Map<String, dynamic>
            ? step
            : Map<String, dynamic>.from(step);
        final polyline = stepMap['polyline'] as Map<String, dynamic>?;
        final encoded = polyline?['points']?.toString();
        if (encoded == null || encoded.isEmpty) continue;
        _appendPolylinePoints(points, _decodePolyline(encoded));
      }
    }

    return points;
  }

  static void _appendPolylinePoints(
    List<LatLng> target,
    List<LatLng> incoming,
  ) {
    for (final point in incoming) {
      if (target.isNotEmpty) {
        final last = target.last;
        if (last.latitude == point.latitude &&
            last.longitude == point.longitude) {
          continue;
        }
      }
      target.add(point);
    }
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
