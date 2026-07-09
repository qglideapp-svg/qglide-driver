/// Canonical driver referral program terms shown in the app UI.
///
/// Driver A earns this amount in their balance when Driver B completes
/// [minRides] rides within [windowDays] days of signing up with the code.
abstract final class DriverReferralProgramTerms {
  static const int minRides = 100;
  static const int windowDays = 30;
  static const double bountyQar = 100;
}
