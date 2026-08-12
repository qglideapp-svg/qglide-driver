import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import 'earnings_panel.dart';

class TransferToCommissionPanel extends StatefulWidget {
  const TransferToCommissionPanel({
    super.key,
    this.isLoading = false,
    this.isProcessing = false,
    this.mainAvailableBalance = 0,
    this.commissionBalance = 0,
    this.onTransfer,
  });

  final bool isLoading;
  final bool isProcessing;
  final double mainAvailableBalance;
  final double commissionBalance;
  final Future<void> Function(double amount)? onTransfer;

  @override
  State<TransferToCommissionPanel> createState() =>
      _TransferToCommissionPanelState();
}

class _TransferToCommissionPanelState extends State<TransferToCommissionPanel> {
  var _balanceVisible = true;
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _amountFocusNode.addListener(_handleAmountFocus);
  }

  @override
  void dispose() {
    _amountFocusNode
      ..removeListener(_handleAmountFocus)
      ..dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _handleAmountFocus() {
    if (!_amountFocusNode.hasFocus) return;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.2,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _fillAllAmount() {
    _amountController.text = widget.mainAvailableBalance.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _handleTransfer() async {
    final onTransfer = widget.onTransfer;
    if (onTransfer == null || widget.isProcessing) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    await onTransfer(amount);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        r.gap(16),
        0,
        r.gap(16),
        r.gap(16) + keyboardInset,
      ),
      child: widget.isLoading
          ? const Padding(
              padding: EdgeInsets.only(top: 24),
              child: LazyBalanceHeader(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!keyboardOpen)
                  _BalanceSummary(
                    balanceVisible: _balanceVisible,
                    mainAvailableBalance: widget.mainAvailableBalance,
                    commissionBalance: widget.commissionBalance,
                    onToggleVisibility: () {
                      setState(() => _balanceVisible = !_balanceVisible);
                    },
                  ),
                if (!keyboardOpen) SizedBox(height: r.gap(24)),
                Text(
                  s.customAmount,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(16).clamp(15.0, 18.0),
                    fontWeight: FontWeight.w600,
                    color: dashboard.primaryText,
                  ),
                ),
                SizedBox(height: r.gap(8)),
                TextField(
                  controller: _amountController,
                  focusNode: _amountFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    hintText: s.enterAmount,
                    hintStyle: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(16).clamp(15.0, 18.0),
                      color: dashboard.mutedText,
                    ),
                    filled: true,
                    fillColor: dashboard.inputFill,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: r.gap(14),
                      vertical: r.h(14),
                    ),
                    suffixIcon: Padding(
                      padding: EdgeInsets.only(right: r.gap(8)),
                      child: TextButton(
                        onPressed: _fillAllAmount,
                        child: Text(
                          s.allAmount,
                          style: TextStyle(
                            fontFamily: AppFonts.satoshi,
                            fontSize: r.sp(14).clamp(13.0, 15.0),
                            fontWeight: FontWeight.w700,
                            color: AppColors.loginButton,
                          ),
                        ),
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.gap(10)),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.gap(10)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.gap(10)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(16).clamp(15.0, 18.0),
                    fontWeight: FontWeight.w500,
                    color: dashboard.primaryText,
                  ),
                ),
                SizedBox(height: r.gap(24)),
                Material(
                  color: AppColors.loginButton,
                  borderRadius: BorderRadius.circular(r.gap(6)),
                  child: InkWell(
                    onTap: widget.isProcessing
                        ? null
                        : () => unawaited(_handleTransfer()),
                    borderRadius: BorderRadius.circular(r.gap(6)),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: r.h(14)),
                      alignment: Alignment.center,
                      child: widget.isProcessing
                          ? SizedBox(
                              width: r.iconSm,
                              height: r.iconSm,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              s.transferToCommission,
                              style: TextStyle(
                                fontFamily: AppFonts.satoshi,
                                fontSize: r.sp(17).clamp(16.0, 19.0),
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({
    required this.balanceVisible,
    required this.mainAvailableBalance,
    required this.commissionBalance,
    required this.onToggleVisibility,
  });

  final bool balanceVisible;
  final double mainAvailableBalance;
  final double commissionBalance;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              s.transferFromMainWallet,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(14).clamp(13.0, 15.0),
                color: dashboard.secondaryText,
              ),
            ),
            SizedBox(width: r.gap(6)),
            InkWell(
              onTap: onToggleVisibility,
              borderRadius: BorderRadius.circular(r.gap(8)),
              child: Padding(
                padding: EdgeInsets.all(r.gap(2)),
                child: Icon(
                  balanceVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: r.iconSm,
                  color: dashboard.mutedText,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.gap(12)),
        Row(
          children: [
            Expanded(
              child: _MiniBalanceCard(
                label: s.mainWalletBalance,
                amount: mainAvailableBalance,
                balanceVisible: balanceVisible,
              ),
            ),
            SizedBox(width: r.gap(10)),
            Expanded(
              child: _MiniBalanceCard(
                label: s.commissionWallet,
                amount: commissionBalance,
                balanceVisible: balanceVisible,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniBalanceCard extends StatelessWidget {
  const _MiniBalanceCard({
    required this.label,
    required this.amount,
    required this.balanceVisible,
  });

  final String label;
  final double amount;
  final bool balanceVisible;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Container(
      padding: EdgeInsets.all(r.gap(12)),
      decoration: BoxDecoration(
        color: dashboard.walletCard,
        borderRadius: BorderRadius.circular(r.gap(12)),
        border: Border.all(color: dashboard.walletCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(12).clamp(11.0, 13.0),
              color: dashboard.secondaryText,
            ),
          ),
          SizedBox(height: r.gap(6)),
          Text(
            balanceVisible ? formatQar(amount) : s.hiddenBalanceShort,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 18.0),
              fontWeight: FontWeight.w900,
              color: dashboard.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
