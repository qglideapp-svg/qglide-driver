import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WazeNavigationService {
  static Future<String?> openNavigation({
    LatLng? coordinates,
    String? address,
  }) async {
    final webUri = _buildWebUri(coordinates: coordinates, address: address);
    if (webUri == null) {
      return 'Location not available for navigation.';
    }

    if (await _tryLaunch(webUri)) {
      return null;
    }

    if (coordinates != null) {
      final appUri = Uri.parse(
        'waze://?ll=${coordinates.latitude},${coordinates.longitude}&navigate=yes',
      );
      if (await _tryLaunch(appUri)) {
        return null;
      }
    }

    return 'Could not open Waze. Make sure it is installed, then restart the app and try again.';
  }

  static Future<bool> _tryLaunch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Uri? _buildWebUri({
    LatLng? coordinates,
    String? address,
  }) {
    if (coordinates != null) {
      return Uri.parse(
        'https://waze.com/ul?ll=${coordinates.latitude},${coordinates.longitude}&navigate=yes',
      );
    }

    final trimmed = address?.trim();
    if (trimmed != null && trimmed.isNotEmpty && trimmed != '--') {
      return Uri.parse(
        'https://waze.com/ul?q=${Uri.encodeComponent(trimmed)}&navigate=yes',
      );
    }

    return null;
  }
}
