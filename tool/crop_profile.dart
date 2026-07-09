import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/profile_avatar.png').readAsBytesSync();
  final source = img.decodePng(bytes)!;

  const cx = 218;
  const cy = 178;
  const size = 168;
  final left = cx - size ~/ 2;
  final top = cy - size ~/ 2;

  final cropped = img.copyCrop(
    source,
    x: left,
    y: top,
    width: size,
    height: size,
  );

  File('assets/profile_photo.png').writeAsBytesSync(img.encodePng(cropped));
  stdout.writeln(
    'Cropped ${source.width}x${source.height} -> '
    '${cropped.width}x${cropped.height} from ($left,$top)',
  );
}
