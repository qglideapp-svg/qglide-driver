import 'package:flutter/material.dart';

import '../../config/app_constants.dart';

class QglidePulseLoader extends StatefulWidget {
  const QglidePulseLoader({super.key, this.size = 96});

  final double size;

  @override
  State<QglidePulseLoader> createState() => _QglidePulseLoaderState();
}

class _QglidePulseLoaderState extends State<QglidePulseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.82, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Image.asset(
        AppConstants.logoIconAsset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );
  }
}

class AuthGoogleLoadingOverlay extends StatelessWidget {
  const AuthGoogleLoadingOverlay({super.key, this.loaderSize = 96});

  final double loaderSize;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: QglidePulseLoader(size: loaderSize),
        ),
      ),
    );
  }
}
