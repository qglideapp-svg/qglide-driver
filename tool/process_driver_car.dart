import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final input = File('assets/icons/driver_car.png');
  final decoded = img.decodeImage(input.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Failed to decode driver_car.png');
    exit(1);
  }

  final image = img.Image.from(decoded);
  final rgba = img.Image(
    width: image.width,
    height: image.height,
    numChannels: 4,
  );

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      rgba.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
    }
  }

  _floodRemoveBackground(rgba);
  input.writeAsBytesSync(img.encodePng(rgba));
  stdout.writeln(
    'Saved transparent driver_car.png (${rgba.width}x${rgba.height}, '
    'channels=${rgba.numChannels})',
  );
}

void _floodRemoveBackground(img.Image image) {
  final w = image.width;
  final h = image.height;
  final visited = List.generate(h, (_) => List.filled(w, false));
  final queue = <(int x, int y)>[];

  bool isBackground(int x, int y) {
    final p = image.getPixel(x, y);
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    final brightness = (r + g + b) / 3;
    final delta = (r - g).abs() + (g - b).abs();
    return brightness > 205 && delta < 55;
  }

  void seed(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h || visited[y][x]) return;
    if (!isBackground(x, y)) return;
    visited[y][x] = true;
    queue.add((x, y));
  }

  for (var x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }

  while (queue.isNotEmpty) {
    final (x, y) = queue.removeLast();
    final p = image.getPixel(x, y);
    image.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 0);

    seed(x + 1, y);
    seed(x - 1, y);
    seed(x, y + 1);
    seed(x, y - 1);
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      if (p.a == 0) continue;
      final brightness = (p.r + p.g + p.b) / 3;
      if (brightness > 238) {
        image.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 0);
      }
    }
  }
}
