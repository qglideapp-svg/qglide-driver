import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the device screen on while the driver is on the home screen.
class ScreenWakeService {
  ScreenWakeService._();

  static var _enabled = false;

  static Future<void> enable() async {
    if (_enabled) return;
    await WakelockPlus.enable();
    _enabled = true;
  }

  static Future<void> disable() async {
    if (!_enabled) return;
    await WakelockPlus.disable();
    _enabled = false;
  }
}
