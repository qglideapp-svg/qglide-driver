import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RoutePosition {
  const RoutePosition({
    required this.point,
    required this.distanceAlongRoute,
    required this.bearing,
  });

  final LatLng point;
  final double distanceAlongRoute;
  final double bearing;
}

class RideRouteProgress {
  RideRouteProgress._();

  static double calculate({
    required LatLng start,
    required LatLng end,
    required LatLng current,
    List<LatLng>? routePoints,
  }) {
    if (routePoints != null && routePoints.length >= 2) {
      final totalMeters = routeLength(routePoints);
      if (totalMeters <= 1) return 1;

      final snapped = snapToRoute(routePoints, current);
      return (snapped.distanceAlongRoute / totalMeters).clamp(0.0, 1.0);
    }

    final totalMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    if (totalMeters <= 1) return 1;

    final remainingMeters = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      end.latitude,
      end.longitude,
    );

    return (1 - (remainingMeters / totalMeters)).clamp(0.0, 1.0);
  }

  static String formatPercent(double progress) {
    return '${(progress.clamp(0.0, 1.0) * 100).round()}%';
  }

  static double routeLength(List<LatLng> route) {
    if (route.length < 2) return 0;

    var total = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      total += _segmentLength(route[i], route[i + 1]);
    }
    return total;
  }

  static RoutePosition snapToRoute(List<LatLng> route, LatLng point) {
    if (route.isEmpty) {
      return RoutePosition(
        point: point,
        distanceAlongRoute: 0,
        bearing: 0,
      );
    }
    if (route.length == 1) {
      return RoutePosition(
        point: route.first,
        distanceAlongRoute: 0,
        bearing: 0,
      );
    }

    var bestDistance = double.infinity;
    var bestPoint = route.first;
    var bestDistanceAlongRoute = 0.0;
    var bestBearing = 0.0;
    var traveled = 0.0;

    for (var i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      final projection = _projectOnSegment(start, end, point);
      final distanceToPoint = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        projection.point.latitude,
        projection.point.longitude,
      );

      if (distanceToPoint < bestDistance) {
        bestDistance = distanceToPoint;
        bestPoint = projection.point;
        bestDistanceAlongRoute = traveled + projection.distanceAlongSegment;
        bestBearing = Geolocator.bearingBetween(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        );
      }

      traveled += _segmentLength(start, end);
    }

    return RoutePosition(
      point: bestPoint,
      distanceAlongRoute: bestDistanceAlongRoute,
      bearing: bestBearing,
    );
  }

  static RoutePosition positionAtDistance(List<LatLng> route, double distance) {
    if (route.isEmpty) {
      return RoutePosition(
        point: const LatLng(0, 0),
        distanceAlongRoute: 0,
        bearing: 0,
      );
    }
    if (route.length == 1 || distance <= 0) {
      return RoutePosition(
        point: route.first,
        distanceAlongRoute: 0,
        bearing: 0,
      );
    }

    final totalLength = routeLength(route);
    if (distance >= totalLength) {
      final last = route.last;
      final previous = route[route.length - 2];
      return RoutePosition(
        point: last,
        distanceAlongRoute: totalLength,
        bearing: Geolocator.bearingBetween(
          previous.latitude,
          previous.longitude,
          last.latitude,
          last.longitude,
        ),
      );
    }

    var traveled = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      final segmentLength = _segmentLength(start, end);
      if (traveled + segmentLength >= distance) {
        final remaining = distance - traveled;
        final t = segmentLength <= 0 ? 0.0 : remaining / segmentLength;
        return RoutePosition(
          point: _interpolateLatLng(start, end, t),
          distanceAlongRoute: distance,
          bearing: Geolocator.bearingBetween(
            start.latitude,
            start.longitude,
            end.latitude,
            end.longitude,
          ),
        );
      }
      traveled += segmentLength;
    }

    return snapToRoute(route, route.last);
  }

  static _SegmentProjection _projectOnSegment(
    LatLng start,
    LatLng end,
    LatLng point,
  ) {
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    final px = point.longitude - start.longitude;
    final py = point.latitude - start.latitude;
    final denom = dx * dx + dy * dy;

    if (denom <= 0) {
      return _SegmentProjection(point: start, distanceAlongSegment: 0);
    }

    final t = (px * dx + py * dy) / denom;
    final clamped = t.clamp(0.0, 1.0);
    final projected = _interpolateLatLng(start, end, clamped);
    final distanceAlongSegment = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      projected.latitude,
      projected.longitude,
    );

    return _SegmentProjection(
      point: projected,
      distanceAlongSegment: distanceAlongSegment,
    );
  }

  static LatLng _interpolateLatLng(LatLng start, LatLng end, double t) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    );
  }

  static double _segmentLength(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  static double _easeInOut(double progress) {
    return progress < 0.5
        ? 2 * progress * progress
        : 1 - math.pow(-2 * progress + 2, 2) / 2;
  }

  static double easedProgress(double progress) {
    return _easeInOut(progress.clamp(0.0, 1.0));
  }
}

class _SegmentProjection {
  const _SegmentProjection({
    required this.point,
    required this.distanceAlongSegment,
  });

  final LatLng point;
  final double distanceAlongSegment;
}
