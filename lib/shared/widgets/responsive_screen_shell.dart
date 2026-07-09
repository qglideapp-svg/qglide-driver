import 'package:flutter/material.dart';

import '../../config/app_responsive.dart';

class ResponsiveScreenShell extends StatelessWidget {
  const ResponsiveScreenShell({
    super.key,
    required this.backgroundAsset,
    required this.child,
    this.padding,
    this.scrollable = true,
    this.footer,
  });

  final String backgroundAsset;
  final Widget child;
  final EdgeInsets? padding;
  final bool scrollable;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final resolvedPadding = padding ?? r.contentPadding;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;

    Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: child,
      ),
    );

    if (footer == null) {
      return Scaffold(
        backgroundColor: scaffoldColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _AuthBackgroundImage(asset: backgroundAsset),
            SafeArea(
              child: scrollable
                  ? SingleChildScrollView(
                      padding: resolvedPadding,
                      child: content,
                    )
                  : Padding(
                      padding: resolvedPadding,
                      child: content,
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _AuthBackgroundImage(asset: backgroundAsset),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: resolvedPadding,
                    child: content,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    resolvedPadding.left,
                    0,
                    resolvedPadding.right,
                    resolvedPadding.bottom,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: r.maxContentWidth),
                      child: footer!,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackgroundImage extends StatelessWidget {
  const _AuthBackgroundImage({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );
  }
}

class ResponsiveGap extends StatelessWidget {
  const ResponsiveGap(this.value, {super.key});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: context.responsive.gap(value));
  }
}

class ResponsiveHGap extends StatelessWidget {
  const ResponsiveHGap(this.value, {super.key});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: context.responsive.gap(value));
  }
}
