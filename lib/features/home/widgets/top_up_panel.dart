import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import 'earnings_panel.dart';

class TopUpPanel extends StatefulWidget {
  const TopUpPanel({
    super.key,
    this.isLoading = false,
    this.isProcessingTopUp = false,
    this.currentBalance = 0,
    this.onTopUp,
  });

  final bool isLoading;
  final bool isProcessingTopUp;
  final double currentBalance;
  final Future<void> Function(double amount)? onTopUp;

  @override
  State<TopUpPanel> createState() => _TopUpPanelState();
}

class _TopUpPanelState extends State<TopUpPanel> {
  static const _presetAmounts = [50.0, 100.0, 200.0];

  var _balanceVisible = true;
  var _selectedPreset = 50.0;
  final _customAmountController = TextEditingController();
  final _customAmountFocusNode = FocusNode();
  var _usesCustomAmount = false;

  @override
  void initState() {
    super.initState();
    _customAmountFocusNode.addListener(_handleCustomAmountFocus);
  }

  @override
  void dispose() {
    _customAmountFocusNode
      ..removeListener(_handleCustomAmountFocus)
      ..dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  void _handleCustomAmountFocus() {
    if (!_customAmountFocusNode.hasFocus) return;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.35,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  double get _selectedAmount {
    if (_usesCustomAmount) {
      return double.tryParse(_customAmountController.text.trim()) ?? 0;
    }
    return _selectedPreset;
  }

  Future<void> _handleTopUp() async {
    final onTopUp = widget.onTopUp;
    if (onTopUp == null || widget.isProcessingTopUp) return;
    await onTopUp(_selectedAmount);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

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
          _CurrentBalanceSection(
            balanceVisible: _balanceVisible,
            currentBalance: widget.currentBalance,
            onToggleVisibility: () {
              setState(() => _balanceVisible = !_balanceVisible);
            },
          ),
          SizedBox(height: r.gap(24)),
          Row(
            children: _presetAmounts
                .map(
                  (amount) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: amount != _presetAmounts.last ? r.gap(8) : 0,
                      ),
                      child: _PresetAmountButton(
                        amount: amount,
                        isSelected: !_usesCustomAmount && _selectedPreset == amount,
                        onTap: () {
                          setState(() {
                            _usesCustomAmount = false;
                            _selectedPreset = amount;
                            _customAmountController.clear();
                          });
                        },
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: r.gap(20)),
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
            controller: _customAmountController,
            focusNode: _customAmountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (value) {
              setState(() => _usesCustomAmount = value.isNotEmpty);
            },
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
              onTap: widget.isProcessingTopUp ? null : () => unawaited(_handleTopUp()),
              borderRadius: BorderRadius.circular(r.gap(6)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: r.h(14)),
                alignment: Alignment.center,
                child: widget.isProcessingTopUp
                    ? SizedBox(
                        width: r.iconSm,
                        height: r.iconSm,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        s.topUp,
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

class _CurrentBalanceSection extends StatelessWidget {
  const _CurrentBalanceSection({
    required this.balanceVisible,
    required this.currentBalance,
    required this.onToggleVisibility,
  });

  final bool balanceVisible;
  final double currentBalance;
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
              s.currentBalance,
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
        SizedBox(height: r.gap(8)),
        Text(
          balanceVisible ? formatQar(currentBalance) : s.hiddenBalanceFull,
          textAlign: TextAlign.center,
          style: balanceAmountTextStyle(r, dashboard.primaryText),
        ),
        SizedBox(height: r.gap(8)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              s.lastUpdatedHoursAgo(2),
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(13).clamp(12.0, 14.0),
                color: dashboard.secondaryText,
              ),
            ),
            SizedBox(width: r.gap(6)),
            Icon(
              Icons.refresh_rounded,
              size: r.iconSm,
              color: dashboard.mutedText,
            ),
          ],
        ),
      ],
    );
  }
}

class _PresetAmountButton extends StatelessWidget {
  const _PresetAmountButton({
    required this.amount,
    required this.isSelected,
    required this.onTap,
  });

  final double amount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);

    return Material(
      color: isSelected ? AppColors.loginButton : dashboard.inputFill,
      borderRadius: BorderRadius.circular(r.gap(6)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.gap(6)),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.h(12)),
          alignment: Alignment.center,
          child: Text(
            s.formatQar(amount, decimals: 1),
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(14).clamp(13.0, 15.0),
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : dashboard.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}
