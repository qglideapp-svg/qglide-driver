class ReferDriverProgressArgs {
  const ReferDriverProgressArgs({
    this.initialReferralCode = '',
  });

  final String initialReferralCode;

  static ReferDriverProgressArgs fromRoute(Object? arguments) {
    if (arguments is ReferDriverProgressArgs) return arguments;
    if (arguments is String) {
      return ReferDriverProgressArgs(initialReferralCode: arguments);
    }
    return const ReferDriverProgressArgs();
  }
}
