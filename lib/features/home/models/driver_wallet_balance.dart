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

class DriverWalletBalance {
  const DriverWalletBalance({
    required this.balance,
    required this.availableBalance,
    required this.rawBalance,
    required this.spendableBalance,
    required this.pendingWithdrawals,
    required this.negativeBalance,
    required this.outstandingDebt,
    required this.effectiveBalance,
    required this.verifiedBalance,
    required this.currency,
    this.walletId,
    this.today,
  });

  final double balance;
  final double availableBalance;
  final double rawBalance;
  final double spendableBalance;
  final double pendingWithdrawals;
  final double negativeBalance;
  final double outstandingDebt;
  final double effectiveBalance;
  final double verifiedBalance;
  final String currency;
  final String? walletId;
  final WalletTodayStats? today;

  double get primaryBalance =>
      availableBalance > 0 ? availableBalance : balance;

  factory DriverWalletBalance.fromPayoutResponse(Map<String, dynamic> json) {
    return DriverWalletBalance.fromJson({
      'balance': json['current'] ?? json['balance'],
      'available_balance': json['available'] ?? json['available_balance'],
      'verified_balance': json['verified_balance'],
      'pending_withdrawals': json['pending_withdrawals'],
      'currency': json['currency'],
    });
  }

  factory DriverWalletBalance.fromJson(Map<String, dynamic> json) {
    return DriverWalletBalance(
      balance: _readWalletDouble(json['balance']),
      availableBalance: _readWalletDouble(json['available_balance']),
      rawBalance: _readWalletDouble(json['raw_balance']),
      spendableBalance: _readWalletDouble(json['spendable_balance']),
      pendingWithdrawals: _readWalletDouble(json['pending_withdrawals']),
      negativeBalance: _readWalletDouble(json['negative_balance']),
      outstandingDebt: _readWalletDouble(json['outstanding_debt']),
      effectiveBalance: _readWalletDouble(json['effective_balance']),
      verifiedBalance: _readWalletDouble(json['verified_balance']),
      currency: json['currency']?.toString() ?? 'QAR',
      walletId: json['wallet_id']?.toString(),
      today: json['today'] is Map<String, dynamic>
          ? WalletTodayStats.fromJson(json['today'] as Map<String, dynamic>)
          : WalletTodayStats(
              ridesCompleted: _readWalletInt(json['rides_completed_today']),
              totalEarnings: _readWalletDouble(json['total_earnings_today']),
            ),
    );
  }
}
