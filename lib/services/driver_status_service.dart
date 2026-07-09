import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DriverDocumentsOnboarding {
  const DriverDocumentsOnboarding({
    required this.complete,
    this.missing = const [],
    this.required = const [],
    this.uploaded = const [],
  });

  final bool complete;
  final List<String> missing;
  final List<String> required;
  final List<String> uploaded;

  factory DriverDocumentsOnboarding.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const DriverDocumentsOnboarding(complete: false);
    }
    return DriverDocumentsOnboarding(
      complete: map['complete'] == true,
      missing: _stringList(map['missing']),
      required: _stringList(map['required']),
      uploaded: _documentTypeList(map['uploaded']),
    );
  }

  static List<String> _documentTypeList(dynamic value) {
    if (value is! List) return const [];

    final types = <String>{};
    for (final item in value) {
      if (item is String && item.trim().isNotEmpty) {
        types.add(item.trim());
        continue;
      }
      if (item is Map) {
        for (final key in const [
          'document_type',
          'documentType',
          'type',
        ]) {
          final docType = item[key]?.toString().trim();
          if (docType != null && docType.isNotEmpty) {
            types.add(docType);
            break;
          }
        }
      }
    }
    return types.toList();
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }
}

class DriverVehicleDetailsOnboarding {
  const DriverVehicleDetailsOnboarding({
    required this.complete,
    this.missingFields = const [],
  });

  final bool complete;
  final List<String> missingFields;

  factory DriverVehicleDetailsOnboarding.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const DriverVehicleDetailsOnboarding(complete: false);
    }
    return DriverVehicleDetailsOnboarding(
      complete: map['complete'] == true,
      missingFields: DriverDocumentsOnboarding._stringList(map['missing_fields']),
    );
  }
}

class DriverOnboarding {
  const DriverOnboarding({
    required this.documents,
    required this.vehicleDetails,
    required this.onboardingComplete,
    this.nextStep,
  });

  final DriverDocumentsOnboarding documents;
  final DriverVehicleDetailsOnboarding vehicleDetails;
  final bool onboardingComplete;
  final String? nextStep;

  factory DriverOnboarding.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const DriverOnboarding(
        documents: DriverDocumentsOnboarding(complete: false),
        vehicleDetails: DriverVehicleDetailsOnboarding(complete: false),
        onboardingComplete: false,
      );
    }
    return DriverOnboarding(
      documents: DriverDocumentsOnboarding.fromMap(
        map['documents'] as Map<dynamic, dynamic>?,
      ),
      vehicleDetails: DriverVehicleDetailsOnboarding.fromMap(
        map['vehicle_details'] as Map<dynamic, dynamic>?,
      ),
      onboardingComplete: map['onboarding_complete'] == true,
      nextStep: map['next_step']?.toString(),
    );
  }
}

class DriverStatus {
  const DriverStatus({
    required this.isVerified,
    required this.isApproved,
    required this.canAcceptRides,
    this.phoneVerified,
    this.onboarding,
  });

  final bool isVerified;
  final bool isApproved;
  final bool canAcceptRides;
  final bool? phoneVerified;
  final DriverOnboarding? onboarding;

  factory DriverStatus.fromMap(Map<dynamic, dynamic> map) {
    DriverOnboarding? onboarding;
    if (map['onboarding'] is Map) {
      onboarding = DriverOnboarding.fromMap(
        map['onboarding'] as Map<dynamic, dynamic>,
      );
    }
    return DriverStatus(
      isVerified: map['is_verified'] == true,
      isApproved: map['is_approved'] == true,
      canAcceptRides: map['can_accept_rides'] == true,
      phoneVerified: _readPhoneVerified(map),
      onboarding: onboarding,
    );
  }

  static bool? _readPhoneVerified(Map<dynamic, dynamic> map) {
    if (!map.containsKey('phone_verified')) return null;
    return map['phone_verified'] == true;
  }

  static bool? readPhoneVerified(Map<dynamic, dynamic> map) =>
      _readPhoneVerified(map);

  bool get isFullyApproved =>
      canAcceptRides || (isVerified && isApproved);
}

enum DriverAccessRoute {
  login,
  phoneVerification,
  dashboard,
  documentUpload,
  manageVehicle,
  pendingApproval,
}

class DriverStatusService {
  static const _warningKey = 'driver_status_warning';
  static const _nextStepKey = 'driver_onboarding_next_step';
  static const _phoneVerifiedKey = 'driver_phone_verified';
  static const _resumeRouteKey = 'driver_signup_resume_route';
  static const _onboardingResponseKey = 'driver_signup_onboarding_response';

  static Map<dynamic, dynamic>? _unwrapApiData(Map<String, dynamic>? response) {
    if (response == null || response['success'] != true) return null;
    final data = response['data'];
    if (data is! Map) return null;
    final apiData = data['data'] ?? data;
    if (apiData is! Map) return null;
    return apiData;
  }

  static DriverStatus? extractFromOnboarding(Map<String, dynamic>? response) {
    if (response == null || response['success'] != true) return null;

    final data = response['data'];
    if (data is! Map) return null;
    final payload = data['data'] is Map ? data['data'] as Map : data;

    if (payload['driver_status'] is Map) {
      return DriverStatus.fromMap(payload['driver_status'] as Map);
    }

    return _fromNestedMap(payload);
  }

  static DriverStatus? extractFromResponse(Map<String, dynamic>? response) {
    return extractFromOnboarding(response) ??
        extractFromLogin(response) ??
        extractFromProfile(response);
  }

  static DriverStatus? extractFromLogin(Map<String, dynamic>? response) {
    if (response == null || response['success'] != true) return null;

    final apiData = _unwrapApiData(response);
    if (apiData != null) {
      final status = _fromNestedMap(apiData);
      if (status != null) return status;
    }

    final data = response['data'];
    if (data is Map) {
      final status = _fromNestedMap(data);
      if (status != null) return status;
      final user = data['user'];
      if (user is Map) {
        return DriverStatus(
          isVerified: false,
          isApproved: false,
          canAcceptRides: false,
          phoneVerified: user['phone_verified'] == true,
        );
      }
    }
    return null;
  }

  static String? extractWarningFromLogin(Map<String, dynamic>? response) {
    final apiData = _unwrapApiData(response);
    if (apiData == null) return null;
    return apiData['warning']?.toString();
  }

  static DriverStatus? extractFromProfile(Map<String, dynamic>? response) {
    if (response == null || response['success'] != true) return null;

    final nestedStatus = _findDriverStatusMap(response['data']);
    if (nestedStatus != null) {
      return DriverStatus.fromMap(nestedStatus);
    }

    final outerData = response['data'];
    if (outerData is! Map) return null;
    final innerData = outerData['data'] ?? outerData;
    if (innerData is! Map) return null;

    final profilePayload = innerData['profile'] is Map
        ? innerData['profile'] as Map<dynamic, dynamic>
        : innerData;

    final profilePhoneVerified =
        DriverStatus.readPhoneVerified(profilePayload) ??
            (profilePayload['personal_details'] is Map
                ? DriverStatus.readPhoneVerified(
                    profilePayload['personal_details'] as Map<dynamic, dynamic>,
                  )
                : null);

    for (final candidate in [
      profilePayload['driver_status'],
      innerData['driver_status'],
      outerData['driver_status'],
      innerData['profile']?['driver_status'],
      innerData['driver']?['driver_status'],
      innerData['driver'],
    ]) {
      if (candidate is Map) {
        final status = _fromNestedMap(candidate);
        if (status != null) {
          return DriverStatus(
            isVerified: status.isVerified,
            isApproved: status.isApproved,
            canAcceptRides: status.canAcceptRides,
            phoneVerified: status.phoneVerified ?? profilePhoneVerified,
            onboarding: status.onboarding,
          );
        }
      }
    }

    final status = _fromNestedMap(profilePayload) ??
        _fromNestedMap(innerData) ??
        _fromNestedMap(outerData);
    if (status != null) {
      return DriverStatus(
        isVerified: status.isVerified,
        isApproved: status.isApproved,
        canAcceptRides: status.canAcceptRides,
        phoneVerified: status.phoneVerified ?? profilePhoneVerified,
        onboarding: status.onboarding,
      );
    }

    if (profilePhoneVerified != null) {
      return DriverStatus(
        isVerified: profilePayload['is_verified'] == true,
        isApproved: false,
        canAcceptRides: false,
        phoneVerified: profilePhoneVerified,
      );
    }

    return null;
  }

  static Map<dynamic, dynamic>? _findDriverStatusMap(dynamic node) {
    if (node is Map) {
      final direct = node['driver_status'];
      if (direct is Map) return direct;
      for (final value in node.values) {
        final found = _findDriverStatusMap(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findDriverStatusMap(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  static DriverStatus? _fromNestedMap(Map<dynamic, dynamic> map) {
    if (map['driver_status'] is Map) {
      return DriverStatus.fromMap(map['driver_status'] as Map);
    }
    if (map.containsKey('is_verified') ||
        map.containsKey('is_approved') ||
        map.containsKey('can_accept_rides') ||
        map.containsKey('onboarding')) {
      return DriverStatus.fromMap(map);
    }
    final profile = map['profile'];
    if (profile is Map) {
      if (profile['driver_status'] is Map) {
        return DriverStatus.fromMap(profile['driver_status'] as Map);
      }
      if (profile.containsKey('is_verified') ||
          profile.containsKey('is_approved') ||
          profile.containsKey('can_accept_rides') ||
          profile.containsKey('onboarding')) {
        return DriverStatus.fromMap(profile);
      }
    }
    return null;
  }

  static DriverStatus? merge(DriverStatus? login, DriverStatus? profile) {
    if (login == null) return profile;
    if (profile == null) return login;

    final loginOnboarding = login.onboarding;
    final profileOnboarding = profile.onboarding;
    final DriverOnboarding? onboarding;
    if (loginOnboarding?.nextStep != null &&
        loginOnboarding!.nextStep!.isNotEmpty) {
      onboarding = loginOnboarding;
    } else if (profileOnboarding?.nextStep != null &&
        profileOnboarding!.nextStep!.isNotEmpty) {
      onboarding = profileOnboarding;
    } else if (loginOnboarding != null || profileOnboarding != null) {
      onboarding = DriverOnboarding(
        documents: loginOnboarding?.documents.complete == true
            ? loginOnboarding!.documents
            : profileOnboarding?.documents ??
                loginOnboarding?.documents ??
                const DriverDocumentsOnboarding(complete: false),
        vehicleDetails: loginOnboarding?.vehicleDetails.complete == true
            ? loginOnboarding!.vehicleDetails
            : profileOnboarding?.vehicleDetails ??
                loginOnboarding?.vehicleDetails ??
                const DriverVehicleDetailsOnboarding(complete: false),
        onboardingComplete: loginOnboarding?.onboardingComplete == true ||
            profileOnboarding?.onboardingComplete == true,
        nextStep: loginOnboarding?.nextStep ?? profileOnboarding?.nextStep,
      );
    } else {
      onboarding = null;
    }

    final merged = DriverStatus(
      isVerified: login.isVerified || profile.isVerified,
      isApproved: login.isApproved || profile.isApproved,
      canAcceptRides: login.canAcceptRides || profile.canAcceptRides,
      phoneVerified: _mergePhoneVerified(login.phoneVerified, profile.phoneVerified),
      onboarding: onboarding,
    );

    if (merged.isFullyApproved) {
      return _asApprovedStatus(merged);
    }
    return merged;
  }

  static bool? _mergePhoneVerified(bool? login, bool? profile) {
    if (login == true || profile == true) return true;
    if (login == false || profile == false) return false;
    return null;
  }

  static DriverStatus _asApprovedStatus(DriverStatus status) {
    return DriverStatus(
      isVerified: status.isVerified,
      isApproved: status.isApproved,
      canAcceptRides: status.canAcceptRides,
      phoneVerified: true,
      onboarding: const DriverOnboarding(
        documents: DriverDocumentsOnboarding(complete: true),
        vehicleDetails: DriverVehicleDetailsOnboarding(complete: true),
        onboardingComplete: true,
        nextStep: 'ready',
      ),
    );
  }

  static DriverAccessRoute resolveRoute({DriverStatus? status}) {
    if (status == null) {
      return DriverAccessRoute.documentUpload;
    }

    if (status.isFullyApproved) {
      return DriverAccessRoute.dashboard;
    }

    if (status.phoneVerified == false) {
      return DriverAccessRoute.phoneVerification;
    }

    final nextStep = status.onboarding?.nextStep?.toLowerCase().trim();

    if (nextStep == 'ready') {
      return DriverAccessRoute.dashboard;
    }
    if (nextStep == 'upload_documents') {
      return DriverAccessRoute.documentUpload;
    }
    if (nextStep == 'manage_vehicle') {
      return DriverAccessRoute.manageVehicle;
    }
    if (nextStep == 'await_approval') {
      return DriverAccessRoute.pendingApproval;
    }

    final onboarding = status.onboarding;
    if (onboarding != null) {
      if (!onboarding.documents.complete) {
        return DriverAccessRoute.documentUpload;
      }
      if (!onboarding.vehicleDetails.complete) {
        return DriverAccessRoute.manageVehicle;
      }
      return DriverAccessRoute.pendingApproval;
    }

    return DriverAccessRoute.documentUpload;
  }

  static Future<void> persist(
    DriverStatus status, {
    String? warningMessage,
    Map<String, dynamic>? statusResponse,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_is_verified', status.isVerified);
    await prefs.setBool('driver_is_approved', status.isApproved);
    await prefs.setBool('driver_can_accept_rides', status.canAcceptRides);
    var nextStep = status.onboarding?.nextStep;
    if ((nextStep == null || nextStep.isEmpty) && status.isFullyApproved) {
      nextStep = 'ready';
    }
    if (nextStep != null && nextStep.isNotEmpty) {
      await prefs.setString(_nextStepKey, nextStep);
    } else {
      await prefs.remove(_nextStepKey);
    }
    if (warningMessage != null && warningMessage.isNotEmpty) {
      await prefs.setString(_warningKey, warningMessage);
    }
    if (status.phoneVerified != null) {
      await prefs.setBool(_phoneVerifiedKey, status.phoneVerified!);
    } else {
      await prefs.remove(_phoneVerifiedKey);
    }

    final resumeRoute = resolveRoute(status: status);
    if (resumeRoute == DriverAccessRoute.dashboard) {
      await clearResumeRoute();
    } else if (_isSignupFunnelRoute(resumeRoute)) {
      await prefs.setString(_resumeRouteKey, resumeRoute.name);
    }

    if (statusResponse != null) {
      await prefs.setString(
        _onboardingResponseKey,
        json.encode(statusResponse),
      );
    }
  }

  static bool _isSignupFunnelRoute(DriverAccessRoute route) {
    return route == DriverAccessRoute.phoneVerification ||
        route == DriverAccessRoute.documentUpload ||
        route == DriverAccessRoute.manageVehicle ||
        route == DriverAccessRoute.pendingApproval;
  }

  static Future<void> recordSignupStep({
    required DriverAccessRoute accessRoute,
    DriverStatus? status,
    Map<String, dynamic>? statusResponse,
  }) async {
    if (status != null) {
      await persist(status, statusResponse: statusResponse);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (_isSignupFunnelRoute(accessRoute)) {
      await prefs.setString(_resumeRouteKey, accessRoute.name);
    }
    if (statusResponse != null) {
      await prefs.setString(
        _onboardingResponseKey,
        json.encode(statusResponse),
      );
    }
  }

  static Future<DriverAccessRoute?> loadResumeRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_resumeRouteKey);
    if (stored == null || stored.isEmpty) return null;
    for (final route in DriverAccessRoute.values) {
      if (route.name == stored) return route;
    }
    return null;
  }

  static Future<void> clearResumeRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_resumeRouteKey);
    await prefs.remove(_onboardingResponseKey);
  }

  static Future<DriverStatus?> loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('driver_is_verified')) return null;
    final isVerified = prefs.getBool('driver_is_verified') ?? false;
    final isApproved = prefs.getBool('driver_is_approved') ?? false;
    final canAcceptRides = prefs.getBool('driver_can_accept_rides') ?? false;
    final phoneVerified =
        prefs.containsKey(_phoneVerifiedKey) ? prefs.getBool(_phoneVerifiedKey) : null;
    var nextStep = prefs.getString(_nextStepKey);
    final fullyApproved = canAcceptRides || (isVerified && isApproved);
    if ((nextStep == null || nextStep.isEmpty) && fullyApproved) {
      nextStep = 'ready';
    }
    return DriverStatus(
      isVerified: isVerified,
      isApproved: isApproved,
      canAcceptRides: canAcceptRides,
      phoneVerified: phoneVerified,
      onboarding: nextStep != null
          ? DriverOnboarding(
              documents: DriverDocumentsOnboarding(
                complete: fullyApproved || nextStep == 'ready',
              ),
              vehicleDetails: DriverVehicleDetailsOnboarding(
                complete: fullyApproved || nextStep == 'ready',
              ),
              onboardingComplete: fullyApproved || nextStep == 'ready',
              nextStep: nextStep,
            )
          : null,
    );
  }

  static Future<void> clearStored() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_warningKey);
    await prefs.remove(_nextStepKey);
    await prefs.remove('driver_is_verified');
    await prefs.remove('driver_is_approved');
    await prefs.remove('driver_can_accept_rides');
    await prefs.remove(_phoneVerifiedKey);
    await clearResumeRoute();
  }

  static Future<DriverAccessRoute?> resolveStoredAccessRoute() async {
    final resumeRoute = await loadResumeRoute();
    if (resumeRoute != null) return resumeRoute;

    final status = await loadStored();
    if (status == null) return null;
    return resolveRoute(status: status);
  }
}
