import '../../../config/app_strings.dart';

/// Backend `REQUIRED_DRIVER_DOCUMENT_TYPES` values for `upload-document`.
abstract final class DriverDocumentType {
  static const qatarId = 'qatar_id';
  static const profilePicture = 'profile_picture';
  static const companyRegistration = 'company_registration';
  static const drivingLicense = 'driving_license';
  static const vehicleInterior = 'vehicle_interior';
  static const vehicleExterior = 'vehicle_exterior';
  static const vehicleRegistrationEstimara = 'vehicle_registration_estimara';

  static const contentStepCount = 3;

  static const all = [
    qatarId,
    profilePicture,
    companyRegistration,
    drivingLicense,
    vehicleInterior,
    vehicleExterior,
    vehicleRegistrationEstimara,
  ];

  static const step1 = [qatarId, profilePicture];
  static const step2 = [
    companyRegistration,
    drivingLicense,
    vehicleInterior,
  ];
  static const step3 = [vehicleExterior, vehicleRegistrationEstimara];

  static List<String> typesForStep(int step) {
    switch (step) {
      case 1:
        return step1;
      case 2:
        return step2;
      case 3:
        return step3;
      default:
        return const [];
    }
  }

  static String label(String type) =>
      AppStrings.current().documentLabel(type);
}
