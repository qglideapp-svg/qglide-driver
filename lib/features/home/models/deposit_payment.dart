class DepositPaymentIntent {
  const DepositPaymentIntent({
    required this.paymentReference,
    required this.checkoutUrl,
    required this.paymentStatus,
    required this.isTest,
  });

  final String paymentReference;
  final String checkoutUrl;
  final String paymentStatus;
  final bool isTest;

  factory DepositPaymentIntent.fromJson(Map<String, dynamic> json) {
    return DepositPaymentIntent(
      paymentReference: json['payment_reference']?.toString() ?? '',
      checkoutUrl: json['checkout_url']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? 'pending',
      isTest: json['is_test'] == true,
    );
  }
}

class TopUpCheckoutArgs {
  const TopUpCheckoutArgs({
    required this.checkoutUrl,
    required this.paymentReference,
    required this.amount,
  });

  final String checkoutUrl;
  final String paymentReference;
  final double amount;
}
