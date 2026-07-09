import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../config/app_theme.dart';
import 'responsive_screen_shell.dart';

class InAppWebView extends StatefulWidget {
  const InAppWebView({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  State<InAppWebView> createState() => _InAppWebViewState();
}

class _InAppWebViewState extends State<InAppWebView> {
  late final WebViewController _controller;
  var _isLoadingPage = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoadingPage = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoadingPage = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final background = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: onSurface,
            size: r.sp(18).clamp(16.0, 20.0),
          ),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(17).clamp(16.0, 19.0),
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoadingPage)
            ColoredBox(
              color: background,
              child: _LazyWebContent(
                primaryColor: onSurface,
                secondaryColor: theme.mutedText,
                surfaceColor: theme.authFieldFill,
              ),
            ),
        ],
      ),
    );
  }
}

class _LazyWebContent extends StatefulWidget {
  const _LazyWebContent({
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;

  @override
  State<_LazyWebContent> createState() => _LazyWebContentState();
}

class _LazyWebContentState extends State<_LazyWebContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            r.gap(20),
            horizontalPadding,
            r.gap(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LazyBlock(
                opacity: opacity,
                color: widget.primaryColor,
                height: r.sp(28).clamp(24.0, 32.0),
                width: r.w(220).clamp(180.0, 260.0),
                borderRadius: r.gap(8),
              ),
              ResponsiveGap(12),
              _LazyBlock(
                opacity: opacity,
                color: widget.secondaryColor,
                height: r.sp(18).clamp(16.0, 20.0),
                width: r.w(160).clamp(130.0, 190.0),
              ),
              ResponsiveGap(24),
              ..._paragraphBlocks(
                r: r,
                opacity: opacity,
                lineCount: 4,
              ),
              ResponsiveGap(20),
              _LazyBlock(
                opacity: opacity,
                color: widget.primaryColor,
                height: r.sp(20).clamp(18.0, 22.0),
                width: r.w(180).clamp(150.0, 220.0),
                borderRadius: r.gap(6),
              ),
              ResponsiveGap(14),
              ..._paragraphBlocks(
                r: r,
                opacity: opacity,
                lineCount: 5,
              ),
              ResponsiveGap(20),
              _LazyBlock(
                opacity: opacity,
                color: widget.primaryColor,
                height: r.sp(20).clamp(18.0, 22.0),
                width: r.w(140).clamp(110.0, 170.0),
                borderRadius: r.gap(6),
              ),
              ResponsiveGap(14),
              ..._paragraphBlocks(
                r: r,
                opacity: opacity,
                lineCount: 4,
              ),
              ResponsiveGap(20),
              _LazyBlock(
                opacity: opacity,
                color: widget.surfaceColor,
                height: r.h(120).clamp(100.0, 140.0),
                borderRadius: r.gap(12),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _paragraphBlocks({
    required AppResponsive r,
    required double opacity,
    required int lineCount,
  }) {
    final widths = [1.0, 0.92, 0.96, 0.78, 0.88];

    return List.generate(lineCount, (index) {
      return Padding(
        padding: EdgeInsets.only(bottom: r.gap(10)),
        child: _LazyBlock(
          opacity: opacity,
          color: widget.surfaceColor,
          height: r.sp(15).clamp(14.0, 16.0),
          width: double.infinity,
          maxWidthFactor: widths[index % widths.length],
        ),
      );
    });
  }
}

class _LazyBlock extends StatelessWidget {
  const _LazyBlock({
    required this.opacity,
    required this.color,
    required this.height,
    this.width,
    this.maxWidthFactor,
    this.borderRadius = 6,
  });

  final double opacity;
  final Color color;
  final double height;
  final double? width;
  final double? maxWidthFactor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: width == null ? maxWidthFactor : null,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
