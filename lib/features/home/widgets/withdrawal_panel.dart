import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/app_colors.dart';
import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/dashboard_theme.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import 'earnings_panel.dart';

class WithdrawalPanel extends StatefulWidget {
  const WithdrawalPanel({
    super.key,
    this.isLoading = false,
    this.isProcessingWithdrawal = false,
    this.availableBalance = 0,
    this.onWithdraw,
  });

  final bool isLoading;
  final bool isProcessingWithdrawal;
  final double availableBalance;
  final Future<void> Function({
    required double amount,
    required String bankAccountName,
    required String bankName,
    required String iban,
    required String accountNumber,
  })? onWithdraw;

  @override
  State<WithdrawalPanel> createState() => _WithdrawalPanelState();
}

class _WithdrawalPanelState extends State<WithdrawalPanel> {
  var _balanceVisible = true;
  final _customAmountController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ibanController = TextEditingController();
  final _accountNumberController = TextEditingController();

  @override
  void dispose() {
    _customAmountController.dispose();
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _ibanController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  void _fillAllAmount() {
    _customAmountController.text = widget.availableBalance.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _handleWithdraw() async {
    final onWithdraw = widget.onWithdraw;
    if (onWithdraw == null || widget.isProcessingWithdrawal) return;

    final amount = double.tryParse(_customAmountController.text.trim()) ?? 0;
    await onWithdraw(
      amount: amount,
      bankAccountName: _accountHolderController.text,
      bankName: _bankNameController.text,
      iban: _ibanController.text,
      accountNumber: _accountNumberController.text,
    );
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
          _AvailableBalanceSection(
            balanceVisible: _balanceVisible,
            availableBalance: widget.availableBalance,
            onToggleVisibility: () {
              setState(() => _balanceVisible = !_balanceVisible);
            },
          ),
          SizedBox(height: r.gap(24)),
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
          _ScrollOnFocusField(
            builder: (focusNode) => TextField(
              controller: _customAmountController,
              focusNode: focusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: _inputDecoration(
                context: context,
                r: r,
                hintText: s.enterAmount,
                suffix: _AllAmountButton(onTap: _fillAllAmount),
              ),
              style: _inputTextStyle(context, r),
            ),
          ),
          SizedBox(height: r.gap(20)),
          Text(
            s.bankDetails,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 18.0),
              fontWeight: FontWeight.w700,
              color: AppColors.loginButton,
            ),
          ),
          SizedBox(height: r.gap(12)),
          _LabeledField(
            label: s.accountHolderName,
            hintText: s.enterName,
            controller: _accountHolderController,
          ),
          SizedBox(height: r.gap(12)),
          _LabeledField(
            label: s.bankName,
            hintText: s.enterBank,
            controller: _bankNameController,
          ),
          SizedBox(height: r.gap(12)),
          _LabeledField(
            label: 'IBAN',
            hintText: s.enterIban,
            controller: _ibanController,
          ),
          SizedBox(height: r.gap(12)),
          _LabeledField(
            label: s.accountNumber,
            hintText: s.enterAccountNumberHint,
            controller: _accountNumberController,
          ),
          SizedBox(height: r.gap(24)),
          Material(
            color: AppColors.loginButton,
            borderRadius: BorderRadius.circular(r.gap(6)),
            child: InkWell(
              onTap: widget.isProcessingWithdrawal
                  ? null
                  : () => unawaited(_handleWithdraw()),
              borderRadius: BorderRadius.circular(r.gap(6)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: r.h(14)),
                alignment: Alignment.center,
                child: widget.isProcessingWithdrawal
                    ? SizedBox(
                        width: r.iconSm,
                        height: r.iconSm,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        s.withdraw,
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

class _AvailableBalanceSection extends StatelessWidget {
  const _AvailableBalanceSection({
    required this.balanceVisible,
    required this.availableBalance,
    required this.onToggleVisibility,
  });

  final bool balanceVisible;
  final double availableBalance;
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
              s.availableBalance,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(16).clamp(15.0, 18.0),
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
          balanceVisible ? formatQar(availableBalance) : s.hiddenBalanceFull,
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

class _LabeledField extends StatefulWidget {
  const _LabeledField({
    required this.label,
    required this.hintText,
    required this.controller,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) return;
    _ScrollOnFocusField.ensureVisible(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(16).clamp(15.0, 18.0),
            fontWeight: FontWeight.w600,
            color: dashboard.primaryText,
          ),
        ),
        SizedBox(height: r.gap(8)),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: _inputDecoration(
            context: context,
            r: r,
            hintText: widget.hintText,
          ),
          style: _inputTextStyle(context, r),
        ),
      ],
    );
  }
}

class _ScrollOnFocusField extends StatefulWidget {
  const _ScrollOnFocusField({required this.builder});

  final Widget Function(FocusNode focusNode) builder;

  static void ensureVisible(BuildContext context) {
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!context.mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.35,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  State<_ScrollOnFocusField> createState() => _ScrollOnFocusFieldState();
}

class _ScrollOnFocusFieldState extends State<_ScrollOnFocusField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) return;
    _ScrollOnFocusField.ensureVisible(context);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_focusNode);
  }
}

class _AllAmountButton extends StatelessWidget {
  const _AllAmountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);

    return Padding(
      padding: EdgeInsets.only(right: r.gap(8)),
      child: Material(
        color: AppColors.loginButton.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(r.gap(6)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(r.gap(6)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.gap(12),
              vertical: r.gap(6),
            ),
            child: Text(
              s.allAmount,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(16).clamp(15.0, 18.0),
                fontWeight: FontWeight.w700,
                color: AppColors.loginButton,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required BuildContext context,
  required AppResponsive r,
  required String hintText,
  Widget? suffix,
}) {
  final dashboard = DashboardTheme.of(context);

  return InputDecoration(
    hintText: hintText,
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
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 0),
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
  );
}

TextStyle _inputTextStyle(BuildContext context, AppResponsive r) {
  final dashboard = DashboardTheme.of(context);

  return TextStyle(
    fontFamily: AppFonts.satoshi,
    fontSize: r.sp(16).clamp(15.0, 18.0),
    fontWeight: FontWeight.w500,
    color: dashboard.primaryText,
  );
}
