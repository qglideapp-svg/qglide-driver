import 'driver_wallet_balance.dart';

class DriverWithdrawalResult {
  const DriverWithdrawalResult({
    required this.message,
    this.walletBalance,
  });

  final String message;
  final DriverWalletBalance? walletBalance;
}
