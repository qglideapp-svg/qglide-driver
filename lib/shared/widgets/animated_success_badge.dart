import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../config/app_constants.dart';
import '../../config/app_responsive.dart';

class AnimatedSuccessBadge extends StatefulWidget {
  const AnimatedSuccessBadge({super.key, this.scale = 1});

  final double scale;

  @override
  State<AnimatedSuccessBadge> createState() => _AnimatedSuccessBadgeState();
}

class _GifFrameData {
  const _GifFrameData(this.image, this.durationMs);

  final ui.Image image;
  final int durationMs;
}

class _AnimatedSuccessBadgeState extends State<AnimatedSuccessBadge> {
  final List<_GifFrameData> _frames = [];
  var _frameIndex = 0;
  Timer? _timer;
  var _isReady = false;
  Brightness? _loadedForBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_loadedForBrightness == brightness) return;

    _loadedForBrightness = brightness;
    _reloadFrames(stripWhiteBackground: brightness == Brightness.dark);
  }

  void _reloadFrames({required bool stripWhiteBackground}) {
    _timer?.cancel();
    for (final frame in _frames) {
      frame.image.dispose();
    }
    _frames.clear();
    _isReady = false;
    _frameIndex = 0;
    _loadAndPlayOnce(stripWhiteBackground: stripWhiteBackground);
  }

  Future<void> _loadAndPlayOnce({required bool stripWhiteBackground}) async {
    try {
      final data = await rootBundle.load(AppConstants.successBadgeAsset);
      final animation = img.decodeGif(data.buffer.asUint8List());
      if (animation == null || animation.numFrames == 0) {
        return;
      }

      for (var i = 0; i < animation.numFrames; i++) {
        final frame = animation.getFrame(i).convert(numChannels: 4);
        if (stripWhiteBackground) {
          _stripNearWhiteBackground(frame);
        }
        final durationMs = frame.frameDuration.clamp(20, 500);
        final uiImage = await _toUiImage(frame);
        _frames.add(_GifFrameData(uiImage, durationMs));
      }

      if (!mounted || _frames.isEmpty) return;

      setState(() {
        _isReady = true;
        _frameIndex = 0;
      });
      _showFrame(0);
    } catch (_) {
      // Keep the reserved space; gif failed to decode.
    }
  }

  void _stripNearWhiteBackground(img.Image image) {
    for (final pixel in image) {
      if (pixel.r >= 235 && pixel.g >= 235 && pixel.b >= 235) {
        pixel.a = 0;
      }
    }
  }

  Future<ui.Image> _toUiImage(img.Image image) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      image.getBytes(order: img.ChannelOrder.rgba),
      image.width,
      image.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  void _showFrame(int index) {
    if (!mounted || _frames.isEmpty) return;

    setState(() => _frameIndex = index);

    if (index >= _frames.length - 1) return;

    _timer?.cancel();
    _timer = Timer(
      Duration(milliseconds: _frames[index].durationMs),
      () => _showFrame(index + 1),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final frame in _frames) {
      frame.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBadge =
        r.w(r.isCompact ? 128 : 146).clamp(108.0, 180.0) * widget.scale;
    final badgeSize = baseBadge.clamp(88.0, 180.0);
    final canvasSize = badgeSize * (widget.scale < 1 ? 1.4 : 1.55);

    return SizedBox(
      width: canvasSize,
      height: canvasSize,
      child: !_isReady || _frames.isEmpty
          ? isDark
              ? const SizedBox.shrink()
              : Image.asset(
                  AppConstants.successBadgeAsset,
                  width: canvasSize,
                  height: canvasSize,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                )
          : RawImage(
              image: _frames[_frameIndex].image,
              width: canvasSize,
              height: canvasSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
    );
  }
}
