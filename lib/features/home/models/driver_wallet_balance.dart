double _readWalletDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _readWalletInt(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class WalletTodayEarnings {
  const WalletTodayEarnings({
    required this.grossAmount,
    required this.commissionAmount,
    required this.netAmount,
    required this.currency,
  });

  final double grossAmount;
  final double commissionAmount;
  final double netAmount;
  final String currency;

  factory WalletTodayEarnings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const WalletTodayEarnings(
        grossAmount: 0,
        commissionAmount: 0,
        netAmount: 0,
        currency: 'QAR',
      );
    }

    return WalletTodayEarnings(
      grossAmount: _readWalletDouble(json['gross_amount']),
      commissionAmount: _readWalletDouble(json['commission_amount']),
      netAmount: _readWalletDouble(json['net_amount']),
      currency: json['currency']?.toString() ?? 'QAR',
    );
  }
}

class WalletTodayStats {
  const WalletTodayStats({
    required this.ridesCompleted,
    required this.totalEarnings,
    this.earnings,
  });

  final int ridesCompleted;
  final double totalEarnings;
  final WalletTodayEarnings? earnings;

  factory WalletTodayStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const WalletTodayStats(ridesCompleted: 0, totalEarnings: 0);
    }

    return WalletTodayStats(
      ridesCompleted: _readWalletInt(
        json['rides_completed'] ?? json['rides_completed_today'],
      ),
      totalEarnings: _readWalletDouble(
        json['total_earnings'] ?? json['total_earnings_today'],
      ),
      earnings: json['earnings'] is Map<String, dynamic>
          ? WalletTodayEarnings.fromJson(
              json['earnings'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// A single wallet account (main earnings or commission pool).
class WalletAccountBalance {
  const WalletAccountBalance({
    required this.balance,
    required this.availableBalance,
    this.currency = 'QAR',
  });

  final double balance;
  final double availableBalance;
  final String currency;

  double get displayBalance =>
      availableBalance > 0 ? availableBalance : balance;

  bool get hasFunds => displayBalance > 0.009;

  factory WalletAccountBalance.fromJson(
    Map<String, dynamic> json, {
    String defaultCurrency = 'QAR',
    double? fallbackBalance,
  }) {
    final balance = _readWalletDouble(
      json['balance'] ??
          json['main_wallet_balance'] ??
          json['earnings_balance'] ??
          fallbackBalance,
    );
    final availableBalance = _readWalletDouble(
      json['available_balance'] ??
          json['available'] ??
          json['main_wallet_balance'] ??
          json['earnings_balance'] ??
          json['balance'] ??
          fallbackBalance,
    );

    return WalletAccountBalance(
      balance: balance,
      availableBalance: availableBalance,
      currency: json['currency']?.toString() ?? defaultCurrency,
    );
  }

  factory WalletAccountBalance.fromAmount(
    double amount, {
    String currency = 'QAR',
  }) {
    return WalletAccountBalance(
      balance: amount,
      availableBalance: amount,
      currency: currency,
    );
  }
}

class DriverWalletBalance {
  const DriverWalletBalance({
    required this.main,
    required this.commission,
    required this.pendingWithdrawals,
    this.today,
    this.canReceiveRides,
  });

  final WalletAccountBalance main;
  final WalletAccountBalance commission;
  final double pendingWithdrawals;
  final WalletTodayStats? today;
  final bool? canReceiveRides;

  /// Main wallet — driver trip earnings and withdrawals.
  double get primaryBalance => main.displayBalance;

  /// Main wallet funds available to withdraw.
  double get availableBalance => main.availableBalance > 0
      ? main.availableBalance
      : main.balance;

  /// Commission wallet — top-ups and QGlide commission deductions.
  double get commissionBalance => commission.displayBalance;

  bool get hasCommissionFunds =>
      canReceiveRides ?? commission.hasFunds;

  // Legacy accessors kept for payout/notification parsing.
  double get balance => main.balance;
  double get rawBalance => commission.balance;
  double get verifiedBalance => main.displayBalance;
  double get spendableBalance => commission.displayBalance;
  double get negativeBalance => 0;
  double get outstandingDebt => 0;
  double get effectiveBalance => main.displayBalance;
  String get currency => main.currency;
  String? get walletId => null;

  factory DriverWalletBalance.fromPayoutResponse(Map<String, dynamic> json) {
    if (_hasDualWalletFields(json)) {
      return DriverWalletBalance.fromJson(json);
    }

    return DriverWalletBalance.fromJson({
      'main_wallet': {
        'balance': json['current'] ?? json['balance'],
        'available_balance': json['available'] ?? json['available_balance'],
        'currency': json['currency'],
      },
      'commission_wallet': json['commission_wallet'],
      'pending_withdrawals': json['pending_withdrawals'],
    });
  }

  factory DriverWalletBalance.fromJson(Map<String, dynamic> json) {
    final currency = json['currency']?.toString() ?? 'QAR';
    final today = json['today'] is Map<String, dynamic>
        ? WalletTodayStats.fromJson(json['today'] as Map<String, dynamic>)
        : WalletTodayStats(
            ridesCompleted: _readWalletInt(json['rides_completed_today']),
            totalEarnings: _readWalletDouble(json['total_earnings_today']),
          );
    final canReceiveRides = json['can_receive_rides'] is bool
        ? json['can_receive_rides'] as bool
        : null;
    final pendingWithdrawals = _readWalletDouble(json['pending_withdrawals']);

    if (json.containsKey('main_wallet_balance') ||
        json.containsKey('commission_balance')) {
      final mainAmount = _readWalletDouble(
        json['main_wallet_balance'] ?? json['earnings_balance'],
      );
      final commissionAmount = _readWalletDouble(json['commission_balance']);
      return DriverWalletBalance(
        main: WalletAccountBalance.fromAmount(mainAmount, currency: currency),
        commission: WalletAccountBalance.fromAmount(
          commissionAmount,
          currency: currency,
        ),
        pendingWithdrawals: pendingWithdrawals,
        today: today,
        canReceiveRides: canReceiveRides,
      );
    }

    final mainWallet = json['main_wallet'];
    final commissionWallet = json['commission_wallet'];
    final earningsBalance = _readWalletDouble(json['earnings_balance']);
    final commissionBalance = _readWalletDouble(json['commission_balance']);

    if (mainWallet is Map<String, dynamic> &&
        commissionWallet is Map<String, dynamic>) {
      return DriverWalletBalance(
        main: WalletAccountBalance.fromJson(
          mainWallet,
          defaultCurrency: currency,
          fallbackBalance: earningsBalance,
        ),
        commission: WalletAccountBalance.fromJson(
          commissionWallet,
          defaultCurrency: currency,
          fallbackBalance: commissionBalance,
        ),
        pendingWithdrawals: pendingWithdrawals,
        today: today,
        canReceiveRides: canReceiveRides,
      );
    }

    if (mainWallet is Map<String, dynamic>) {
      return DriverWalletBalance(
        main: WalletAccountBalance.fromJson(
          mainWallet,
          defaultCurrency: currency,
          fallbackBalance: earningsBalance,
        ),
        commission: WalletAccountBalance.fromAmount(
          commissionBalance,
          currency: currency,
        ),
        pendingWithdrawals: pendingWithdrawals,
        today: today,
        canReceiveRides: canReceiveRides,
      );
    }

    if (commissionWallet is Map<String, dynamic>) {
      return DriverWalletBalance(
        main: WalletAccountBalance.fromAmount(
          earningsBalance > 0
              ? earningsBalance
              : _readWalletDouble(json['available_balance'] ?? json['balance']),
          currency: currency,
        ),
        commission: WalletAccountBalance.fromJson(
          commissionWallet,
          defaultCurrency: currency,
          fallbackBalance: commissionBalance,
        ),
        pendingWithdrawals: pendingWithdrawals,
        today: today,
        canReceiveRides: canReceiveRides,
      );
    }

    if (earningsBalance > 0 || commissionBalance > 0) {
      return DriverWalletBalance(
        main: WalletAccountBalance.fromAmount(
          earningsBalance > 0
              ? earningsBalance
              : _readWalletDouble(json['available_balance'] ?? json['balance']),
          currency: currency,
        ),
        commission: WalletAccountBalance.fromAmount(
          commissionBalance,
          currency: currency,
        ),
        pendingWithdrawals: pendingWithdrawals,
        today: today,
        canReceiveRides: canReceiveRides,
      );
    }

    final available = _readWalletDouble(json['available_balance']);
    final legacyBalance = _readWalletDouble(json['balance']);
    final mainAvailable = available > 0 ? available : legacyBalance;
    final legacyCommission = _firstNonZero([
      commissionBalance,
      _readWalletDouble(json['raw_balance']),
      _readWalletDouble(json['spendable_balance']),
    ]);

    return DriverWalletBalance(
      main: WalletAccountBalance(
        balance: legacyBalance > 0 ? legacyBalance : mainAvailable,
        availableBalance: mainAvailable,
        currency: currency,
      ),
      commission: WalletAccountBalance.fromAmount(
        legacyCommission,
        currency: currency,
      ),
      pendingWithdrawals: pendingWithdrawals,
      today: today,
      canReceiveRides: canReceiveRides,
    );
  }

  static bool _hasDualWalletFields(Map<String, dynamic> json) {
    return json.containsKey('main_wallet_balance') ||
        json.containsKey('commission_balance') ||
        json['main_wallet'] is Map<String, dynamic> ||
        json['commission_wallet'] is Map<String, dynamic> ||
        json.containsKey('earnings_balance');
  }

  static double _firstNonZero(List<double> values) {
    for (final value in values) {
      if (value != 0) return value;
    }
    return 0;
  }
}
