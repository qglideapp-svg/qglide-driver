import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import '../config/app_strings.dart';
import '../services/app_locale_service.dart';

class AdPlacementPayload {
  const AdPlacementPayload({
    required this.showToAllUsers,
    required this.headline,
    required this.supportingCopy,
    required this.creativeImageUrl,
    required this.buttonLabel,
    required this.deepLink,
    required this.androidLink,
    required this.iosLink,
    required this.updatedAt,
  });

  final bool showToAllUsers;
  final String headline;
  final String supportingCopy;
  final String creativeImageUrl;
  final String buttonLabel;
  final String deepLink;
  final String androidLink;
  final String iosLink;
  final String updatedAt;

  bool contentEquals(AdPlacementPayload? other) {
    if (other == null) return false;
    return showToAllUsers == other.showToAllUsers &&
        headline == other.headline &&
        supportingCopy == other.supportingCopy &&
        creativeImageUrl == other.creativeImageUrl &&
        buttonLabel == other.buttonLabel &&
        deepLink == other.deepLink &&
        androidLink == other.androidLink &&
        iosLink == other.iosLink &&
        updatedAt == other.updatedAt;
  }

  String resolveLinkForPlatform() {
    if (!kIsWeb && Platform.isIOS) {
      if (iosLink.isNotEmpty) return iosLink;
      if (deepLink.isNotEmpty) return deepLink;
      return AppConstants.iosAppStoreUrl;
    }

    if (!kIsWeb && Platform.isAndroid) {
      if (androidLink.isNotEmpty) return androidLink;
      if (deepLink.isNotEmpty) return deepLink;
      return AppConstants.androidPlayStoreUrl;
    }

    if (androidLink.isNotEmpty) return androidLink;
    if (iosLink.isNotEmpty) return iosLink;
    if (deepLink.isNotEmpty) return deepLink;
    return AppConstants.androidPlayStoreUrl;
  }

  static AdPlacementPayload? fromApiResponse(
    Map<String, dynamic> result, {
    bool requireShowToAllUsers = false,
  }) {
    if (result['success'] != true) return null;

    final root = result['data'];
    if (root is! Map) return null;
    final rootMap = Map<String, dynamic>.from(root);

    final placement = rootMap['placement'];
    if (placement is! Map) return null;
    final placementMap = Map<String, dynamic>.from(placement);

    if (requireShowToAllUsers && placementMap['show_to_all_users'] != true) {
      return null;
    }

    final isArabic = AppLocaleService.instance.isArabic;
    var headline = _localizedField(
      placementMap,
      primaryKey: 'headline',
      arabicKey: 'headline_ar',
      isArabic: isArabic,
    );
    if (headline.isEmpty) return null;

    final buttonLabelRaw = _localizedField(
      placementMap,
      primaryKey: 'button_label',
      arabicKey: 'button_label_ar',
      isArabic: isArabic,
      fallback: 'Learn more',
    );

    return AdPlacementPayload(
      showToAllUsers: placementMap['show_to_all_users'] == true,
      headline: headline,
      supportingCopy: _localizedField(
        placementMap,
        primaryKey: 'supporting_copy',
        arabicKey: 'supporting_copy_ar',
        isArabic: isArabic,
      ),
      creativeImageUrl:
          (placementMap['creative_image_url'] ?? '').toString().trim(),
      buttonLabel: buttonLabelRaw.isEmpty ? 'Learn more' : buttonLabelRaw,
      deepLink: (placementMap['deep_link'] ?? '').toString().trim(),
      androidLink: (placementMap['android_link'] ?? '').toString().trim(),
      iosLink: (placementMap['ios_link'] ?? '').toString().trim(),
      updatedAt: (placementMap['updated_at'] ?? '').toString().trim(),
    );
  }

  static String _localizedField(
    Map<String, dynamic> map, {
    required String primaryKey,
    required String arabicKey,
    required bool isArabic,
    String fallback = '',
  }) {
    if (isArabic) {
      final arabic = (map[arabicKey] ?? '').toString().trim();
      if (arabic.isNotEmpty) return arabic;
    }
    final primary = (map[primaryKey] ?? fallback).toString().trim();
    return _translateKnownAdCopy(primary, isArabic);
  }

  static String _translateKnownAdCopy(String value, bool isArabic) {
    if (!isArabic) return value;
    final s = AppStrings.current();
    switch (value) {
      case "We've Made Room For You":
        return s.adHeadlineRoomForYou;
      case 'Drivers need that push too':
        return s.driversNeedPush;
      case 'Learn more':
      case 'Learn More':
        return s.learnMore;
      case '20% Discount on Eid Rides':
        return s.eidDiscountAd;
      default:
        return value;
    }
  }

  bool get shouldShowForCurrentUser => showToAllUsers;

  /// Force-update modal: block only when this platform has its store link.
  bool get shouldShowForceUpdateOnCurrentPlatform {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidLink.isNotEmpty;
      case TargetPlatform.iOS:
        return iosLink.isNotEmpty;
      default:
        return false;
    }
  }

  /// Store URL for force-update on the current platform (no deep_link fallback).
  String? forceUpdateLinkForCurrentPlatform() {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return iosLink.isNotEmpty ? iosLink : null;
      case TargetPlatform.android:
        return androidLink.isNotEmpty ? androidLink : null;
      default:
        return null;
    }
  }
}
