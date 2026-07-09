import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';

enum AuthToastVariant { error, warning, success }

class AuthTopToast {
  AuthTopToast._();

  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  static void showError(BuildContext context, String message) {
    show(context, message: message, variant: AuthToastVariant.error);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message: message, variant: AuthToastVariant.warning);
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, variant: AuthToastVariant.success);
  }

  static void show(
    BuildContext context, {
    required String message,
    AuthToastVariant variant = AuthToastVariant.error,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    _dismissTimer?.cancel();
    _entry?.remove();
    _entry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _AuthTopToastBanner(
        message: trimmed,
        variant: variant,
        onDismiss: () => _removeEntry(entry),
      ),
    );

    _entry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(const Duration(seconds: 4), () => _removeEntry(entry));
  }

  static void _removeEntry(OverlayEntry entry) {
    if (_entry == entry) {
      _dismissTimer?.cancel();
      _dismissTimer = null;
      _entry?.remove();
      _entry = null;
    }
  }
}

class _AuthTopToastBanner extends StatefulWidget {
  const _AuthTopToastBanner({
    required this.message,
    required this.variant,
    required this.onDismiss,
  });

  final String message;
  final AuthToastVariant variant;
  final VoidCallback onDismiss;

  @override
  State<_AuthTopToastBanner> createState() => _AuthTopToastBannerState();
}

class _AuthTopToastBannerState extends State<_AuthTopToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final scheme = Theme.of(context).colorScheme;
    final accent = _accentColor(widget.variant);
    final icon = _icon(widget.variant);
    final title = _title(widget.variant);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(r.gap(16), r.gap(10), r.gap(16), 0),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(r.borderRadiusLg),
                    border: Border.all(color: accent.withValues(alpha: 0.28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(r.borderRadiusLg),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 5, color: accent),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                r.gap(14),
                                r.gap(14),
                                r.gap(8),
                                r.gap(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(r.gap(8)),
                                      child: Icon(
                                        icon,
                                        size: r.iconSm,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: r.gap(12)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontFamily: AppFonts.plusJakartaSans,
                                            fontSize: r.captionSize,
                                            fontWeight: FontWeight.w700,
                                            color: scheme.onSurface,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                        SizedBox(height: r.gap(4)),
                                        Text(
                                          widget.message,
                                          style: TextStyle(
                                            fontFamily: AppFonts.plusJakartaSans,
                                            fontSize: r.bodySize,
                                            fontWeight: FontWeight.w500,
                                            height: 1.35,
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.82),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _dismiss,
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: r.iconSm,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _accentColor(AuthToastVariant variant) {
    return switch (variant) {
      AuthToastVariant.error => const Color(0xFFCE0000),
      AuthToastVariant.warning => AppColors.accentYellowSolid,
      AuthToastVariant.success => const Color(0xFF1B8A4A),
    };
  }

  IconData _icon(AuthToastVariant variant) {
    return switch (variant) {
      AuthToastVariant.error => Icons.error_outline_rounded,
      AuthToastVariant.warning => Icons.info_outline_rounded,
      AuthToastVariant.success => Icons.check_circle_outline_rounded,
    };
  }

  String _title(AuthToastVariant variant) {
    return switch (variant) {
      AuthToastVariant.error => 'Check your details',
      AuthToastVariant.warning => 'Heads up',
      AuthToastVariant.success => 'Success',
    };
  }
}

mixin AuthValidationToastState<T extends StatefulWidget> on State<T> {
  String? _shownAuthError;

  void presentAuthValidationError(String? error) {
    if (error != null && error != _shownAuthError) {
      _shownAuthError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AuthTopToast.showError(context, error);
      });
    } else if (error == null) {
      _shownAuthError = null;
    }
  }
}
