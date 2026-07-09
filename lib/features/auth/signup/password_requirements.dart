class PasswordRequirements {
  const PasswordRequirements({
    required this.hasMinLength,
    required this.hasNumber,
    required this.hasSymbol,
  });

  final bool hasMinLength;
  final bool hasNumber;
  final bool hasSymbol;

  bool get isMet => hasMinLength && hasNumber && hasSymbol;

  static PasswordRequirements evaluate(String password) {
    return PasswordRequirements(
      hasMinLength: password.length >= 8,
      hasNumber: RegExp(r'[0-9]').hasMatch(password),
      hasSymbol: RegExp(r'[^a-zA-Z0-9]').hasMatch(password),
    );
  }
}
