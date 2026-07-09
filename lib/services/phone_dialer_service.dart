import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneDialerService {
  static Future<String?> launch(String? rawPhone) async {
    final cleaned = _normalizeForDialer(rawPhone);
    if (cleaned == null) {
      return 'Rider phone number is not available.';
    }

    final uri = Uri.parse('tel:$cleaned');

    const modes = [
      LaunchMode.platformDefault,
      LaunchMode.externalApplication,
      LaunchMode.externalNonBrowserApplication,
    ];

    for (final mode in modes) {
      try {
        if (await launchUrl(uri, mode: mode)) {
          return null;
        }
      } on PlatformException {
        continue;
      } catch (_) {
        continue;
      }
    }

    return 'Could not open the phone dialer.';
  }

  static String? _normalizeForDialer(String? rawPhone) {
    final trimmed = rawPhone?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      final char = trimmed[i];
      if (char == '+' && buffer.isEmpty) {
        buffer.write(char);
      } else if (RegExp(r'\d').hasMatch(char)) {
        buffer.write(char);
      }
    }

    final cleaned = buffer.toString();
    return cleaned.isEmpty ? null : cleaned;
  }
}
