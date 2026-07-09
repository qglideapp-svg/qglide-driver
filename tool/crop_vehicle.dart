import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final source = img.decodeImage(
    File(
      '/Users/apple/.cursor/projects/Users-apple-Downloads-Archive-qglide-driver/assets/image-89db083c-c31e-449a-bca9-535ba0d28b23.png',
    ).readAsBytesSync(),
  )!;
  final cropped = img.copyCrop(
    source,
    x: 16,
    y: 108,
    width: 434,
    height: 284,
  );
  File('assets/manage_vehicle_photo.png').writeAsBytesSync(img.encodePng(cropped));
}
