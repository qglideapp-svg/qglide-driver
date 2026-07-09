import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image/image.dart' as img;

import '../../../config/app_colors.dart';

class MapMarkerIcons {
  MapMarkerIcons._();

  static const _driverCarAsset = 'assets/icons/driver_car.png';

  static Future<BitmapDescriptor> driverCarMarker({
    double targetWidth = 56,
  }) async {
    try {
      final data = await rootBundle.load(_driverCarAsset);
      final decoded = img.decodeImage(data.buffer.asUint8List());
      if (decoded == null) {
        return driverLocationPointer();
      }

      final resized = img.copyResize(
        decoded,
        width: targetWidth.round(),
        interpolation: img.Interpolation.linear,
      );

      final png = Uint8List.fromList(img.encodePng(resized));
      return BitmapDescriptor.bytes(
        png,
        width: targetWidth,
      );
    } catch (_) {
      return driverLocationPointer();
    }
  }

  static Future<BitmapDescriptor> driverLocationPointer() async {
    const size = 128.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final glowLayers = [
      (radius: 54.0, color: AppColors.loginButton.withValues(alpha: 0.14)),
      (radius: 44.0, color: AppColors.loginButton.withValues(alpha: 0.22)),
      (radius: 36.0, color: AppColors.loginButton.withValues(alpha: 0.30)),
    ];

    for (final layer in glowLayers) {
      canvas.drawCircle(
        center,
        layer.radius,
        Paint()..color = layer.color,
      );
    }

    canvas.drawCircle(
      center,
      24,
      Paint()..color = AppColors.loginButton,
    );
    canvas.drawCircle(
      center,
      10,
      Paint()..color = Colors.white,
    );

    return _toBitmapDescriptor(recorder, size);
  }

  static Future<BitmapDescriptor> pickupPin() async {
    const width = 72.0;
    const height = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final tip = Offset(width / 2, height - 6);
    final headCenter = Offset(width / 2, 28);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(width / 2, height - 2),
        width: 24,
        height: 8,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );

    final pinPath = Path()
      ..addOval(Rect.fromCircle(center: headCenter, radius: 22))
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(headCenter.dx - 14, headCenter.dy + 8)
      ..lineTo(headCenter.dx + 14, headCenter.dy + 8)
      ..close();

    canvas.drawPath(pinPath, Paint()..color = AppColors.loginButton);
    canvas.drawCircle(headCenter, 7, Paint()..color = Colors.white);

    return _toBitmapDescriptor(recorder, width, height);
  }

  static Future<BitmapDescriptor> _toBitmapDescriptor(
    ui.PictureRecorder recorder,
    double width, [
    double? height,
  ]) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      width.ceil(),
      (height ?? width).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
