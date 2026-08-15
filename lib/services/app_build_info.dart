import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppBuildInfo {
  AppBuildInfo._();

  static Future<int?> currentBuildNumber() async {
    if (kIsWeb) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber);
    } catch (_) {
      return null;
    }
  }

  static String? forceUpdatePlatform() {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
  }
}
