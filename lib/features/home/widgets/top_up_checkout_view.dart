import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../services/auth_service.dart';
import '../models/deposit_payment.dart';
import 'earnings_panel.dart';

class TopUpCheckoutView extends StatefulWidget {
  const TopUpCheckoutView({super.key, required this.args});

  final TopUpCheckoutArgs args;

  @override
  State<TopUpCheckoutView> createState() => _TopUpCheckoutViewState();
}

class _TopUpCheckoutViewState extends State<TopUpCheckoutView> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  var _isLoadingPage = true;
  var _isCheckingStatus = false;
  var _hasCompleted = false;
  var _checkoutStarted = false;
  var _showConfirmingOverlay = false;
  String? _tapChargeId;

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
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoadingPage = false);
            unawaited(_inspectPageForPaymentReturn(url));
          },
          onNavigationRequest: (request) {
            _handleNavigation(request.url);
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _handleNavigation(url);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.args.checkoutUrl));
    _checkoutStarted = true;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool _isPaymentReturnUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    if (_isPaymentCancelUrl(url)) return false;

    final action = uri.queryParameters['action']?.toLowerCase();
    if (action == 'return') return true;
    if (uri.queryParameters.containsKey('tap_id')) return true;

    final lower = url.toLowerCase();
    return lower.contains('payment complete') ||
        (lower.contains('process-deposit') && action == 'return');
  }

  bool _isPaymentCancelUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final status = _normalizeStatus(
      uri.queryParameters['status'] ??
          uri.queryParameters['payment_status'] ??
          uri.queryParameters['charge_status'],
    );
    if (status != null &&
        _isTerminalStatus(status) &&
        !_isSuccessStatus(status)) {
      return true;
    }

    final lower = url.toLowerCase();
    return lower.contains('payment-cancel') ||
        lower.contains('payment_cancel') ||
        lower.contains('cancelled=true') ||
        lower.contains('canceled=true') ||
        lower.contains('status=cancelled') ||
        lower.contains('status=canceled') ||
        lower.contains('status=failed') ||
        lower.contains('status=declined');
  }

  String? _normalizeStatus(String? status) {
    final normalized = status?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  String? _extractTapChargeId(String url) {
    final uri = Uri.tryParse(url);
    final tapId = uri?.queryParameters['tap_id'];
    if (tapId != null && tapId.isNotEmpty) return tapId;

    final match = RegExp(r'tap_id=([^\s&<"]+)').firstMatch(url);
    return match?.group(1);
  }

  void _handleNavigation(String url) {
    if (_hasCompleted) return;

    final tapId = _extractTapChargeId(url);
    if (tapId != null) _tapChargeId = tapId;

    if (_isPaymentCancelUrl(url)) {
      unawaited(_handlePaymentCancelled());
      return;
    }

    if (_isPaymentReturnUrl(url)) {
      unawaited(_handlePaymentReturn());
      return;
    }

    final lower = url.toLowerCase();
    if (lower.contains('redirect') ||
        lower.contains('callback') ||
        lower.contains('success') ||
        lower.contains('cancel') ||
        lower.contains('failure') ||
        lower.contains('failed') ||
        lower.contains('complete')) {
      unawaited(_checkPaymentStatus(showErrors: false));
      _startPolling();
      return;
    }

    if (!_checkoutStarted) return;
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.isNotEmpty && !host.contains('tap.company')) {
      unawaited(_checkPaymentStatus(showErrors: false));
      _startPolling();
    }
  }

  Future<void> _inspectPageForPaymentReturn(String url) async {
    if (_hasCompleted) return;

    if (_isPaymentCancelUrl(url)) {
      await _handlePaymentCancelled();
      return;
    }

    if (_isPaymentReturnUrl(url)) {
      await _handlePaymentReturn();
      return;
    }

    try {
      final title = (await _controller.getTitle())?.toLowerCase() ?? '';
      if (title != 'payment') return;

      final result = await _controller.runJavaScriptReturningResult(
        'document.body ? document.body.innerText : ""',
      );
      final pageText = result.toString().toLowerCase();
      if (pageText.contains('cancelled') ||
          pageText.contains('canceled') ||
          pageText.contains('payment failed') ||
          pageText.contains('payment declined')) {
        await _handlePaymentCancelled();
        return;
      }
      if (pageText.contains('payment complete') ||
          pageText.contains('action=return') ||
          pageText.contains('tap_id=')) {
        final tapId = RegExp(r'tap_id=([^\s&<"]+)')
            .firstMatch(pageText)
            ?.group(1);
        if (tapId != null) _tapChargeId = tapId;
        await _handlePaymentReturn();
      }
    } catch (_) {}
  }

  void _showConfirmingState() {
    if (!mounted || _showConfirmingOverlay) return;
    setState(() => _showConfirmingOverlay = true);
  }

  Future<void> _handlePaymentCancelled() async {
    if (_hasCompleted) return;

    _showConfirmingState();
    _startPolling();

    await _checkPaymentStatus(showErrors: false);
    if (_hasCompleted) return;

    _complete(success: false);
  }

  Future<void> _handlePaymentReturn() async {
    if (_hasCompleted) return;

    _showConfirmingState();
    _startPolling();

    for (var attempt = 0; attempt < 10; attempt++) {
      if (_hasCompleted) return;
      await _checkPaymentStatus(showErrors: false);
      if (_hasCompleted) return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    if (!mounted || _hasCompleted) return;
    _complete(success: false);
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_checkPaymentStatus(showErrors: false)),
    );
  }

  bool _isSuccessStatus(String status) {
    return status == 'captured' ||
        status == 'paid' ||
        status == 'success' ||
        status == 'succeeded' ||
        status == 'completed' ||
        status == 'complete' ||
        status == 'authorized' ||
        status == 'approved';
  }

  bool _isPendingStatus(String status) {
    return status == 'pending' ||
        status == 'initiated' ||
        status == 'in_progress' ||
        status == 'processing' ||
        status == 'created' ||
        status == 'open';
  }

  Future<void> _checkPaymentStatus({bool showErrors = true}) async {
    if (_hasCompleted || _isCheckingStatus) return;

    setState(() => _isCheckingStatus = true);

    final response = await AuthService.getDepositPaymentStatus(
      paymentReference: widget.args.paymentReference,
      tapChargeId: _tapChargeId,
    );
    final status = AuthService.extractDepositPaymentStatus(response);

    if (!mounted) return;

    setState(() => _isCheckingStatus = false);

    if (status == null) {
      if (showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthService.extractErrorMessage(
                response,
                fallback: 'Could not verify payment status.',
              ),
            ),
          ),
        );
      }
      return;
    }

    if (_isSuccessStatus(status)) {
      _complete(success: true);
      return;
    }

    if (_isTerminalStatus(status)) {
      _complete(success: false);
      return;
    }

    if (_isPendingStatus(status)) {
      return;
    }
  }

  bool _isTerminalStatus(String status) {
    return status == 'failed' ||
        status == 'failure' ||
        status == 'cancelled' ||
        status == 'canceled' ||
        status == 'declined' ||
        status == 'expired' ||
        status == 'abandoned' ||
        status == 'void' ||
        status == 'voided' ||
        status == 'timedout' ||
        status == 'timeout' ||
        status == 'rejected';
  }

  void _complete({required bool success}) {
    if (_hasCompleted) return;
    _hasCompleted = true;
    _pollTimer?.cancel();
    Navigator.of(context).pop(success);
  }

  Future<void> _closeCheckout() async {
    await _checkPaymentStatus(showErrors: false);
    if (!mounted || _hasCompleted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Scaffold(
      backgroundColor: dashboard.scaffold,
      appBar: AppBar(
        backgroundColor: dashboard.scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _hasCompleted || _showConfirmingOverlay
              ? null
              : () => unawaited(_closeCheckout()),
          icon: Icon(
            Icons.close_rounded,
            color: dashboard.primaryText,
          ),
        ),
        title: Text(
          s.topUpCheckoutTitle(formatQar(widget.args.amount)),
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(17).clamp(16.0, 19.0),
            fontWeight: FontWeight.w700,
            color: dashboard.primaryText,
          ),
        ),
        actions: [
          if (_isCheckingStatus || _isLoadingPage || _showConfirmingOverlay)
            Padding(
              padding: EdgeInsets.only(right: r.gap(16)),
              child: Center(
                child: SizedBox(
                  width: r.iconSm,
                  height: r.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.loginButton,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoadingPage)
            ColoredBox(
              color: dashboard.scaffold,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.loginButton),
              ),
            ),
          if (_showConfirmingOverlay)
            ColoredBox(
              color: dashboard.scaffold,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.gap(32)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: r.iconMd * 2,
                        height: r.iconMd * 2,
                        child: CircularProgressIndicator(
                          color: AppColors.loginButton,
                        ),
                      ),
                      SizedBox(height: r.gap(16)),
                      Text(
                        s.confirmingPayment,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.satoshi,
                          fontSize: r.sp(18).clamp(17.0, 20.0),
                          fontWeight: FontWeight.w700,
                          color: dashboard.primaryText,
                        ),
                      ),
                      SizedBox(height: r.gap(8)),
                      Text(
                        s.returningToWallet,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.satoshi,
                          fontSize: r.sp(14).clamp(13.0, 16.0),
                          color: dashboard.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
