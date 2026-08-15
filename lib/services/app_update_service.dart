import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_constants.dart';
import '../config/app_strings.dart';
import '../features/app_update/app_update_required_card.dart';
import '../models/ad_placement_payload.dart';
import 'ad_placement_service.dart';
import 'app_build_info.dart';

class AppUpdateService {
  AppUpdateService._();

  static const pollInterval = Duration(seconds: 4);

  static var _started = false;
  static var _initialCheckComplete = false;
  static Timer? _timer;
  static Future<bool>? _pollInFlight;
  static AdPlacementPayload? _activePlacement;
  static final placementNotifier = ValueNotifier<AdPlacementPayload?>(null);
  static final _readyCompleter = Completer<void>();

  static AdPlacementPayload? get activePlacement => _activePlacement;

  static bool get isBlocking => _activePlacement != null;

  static Future<void> waitUntilReady() async {
    if (_initialCheckComplete) return;
    await _readyCompleter.future;
  }

  static void startPolling() {
    if (kIsWeb) return;
    final needsInitialCheck = !_started;
    _started = true;
    _timer?.cancel();
    if (needsInitialCheck) {
      unawaited(_ensureInitialCheckComplete());
    } else {
      unawaited(_poll());
    }
    _timer = Timer.periodic(pollInterval, (_) {
      unawaited(_poll());
    });
  }

  static Future<void> _ensureInitialCheckComplete() async {
    await _poll();
    _markReady();
  }

  static void _markReady() {
    if (_initialCheckComplete) return;
    _initialCheckComplete = true;
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  static void stopPolling() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }

  static void refreshNow() {
    if (kIsWeb) return;
    unawaited(_poll());
  }

  static void refreshForLocaleChange() {
    if (kIsWeb) return;
    _applyPlacement(null);
    unawaited(_poll());
  }

  /// Returns `true` when the backend force-update placement is active.
  static Future<bool> enforceUpdateIfNeeded() {
    return _poll();
  }

  static Future<bool> _poll() {
    final inFlight = _pollInFlight;
    if (inFlight != null) return inFlight;

    final poll = _pollImpl();
    _pollInFlight = poll;
    return poll.whenComplete(() => _pollInFlight = null);
  }

  static Future<bool> _pollImpl() async {
    if (kIsWeb) return false;

    try {
      final placement = await _loadPlacement();
      _applyPlacement(placement);
      return placement != null;
    } finally {
      _markReady();
    }
  }

  static void _applyPlacement(AdPlacementPayload? placement) {
    final wasBlocking = isBlocking;
    _activePlacement = placement;
    placementNotifier.value = placement;
    if (wasBlocking != isBlocking) {
      _onBlockingStateChanged(isBlocking);
    }
  }

  static void _onBlockingStateChanged(bool blocking) {
    if (blocking) {
      AdPlacementCache.instance.stop();
    } else {
      AdPlacementCache.instance.start();
    }
  }

  static Future<AdPlacementPayload?> _loadPlacement() async {
    final platform = AppBuildInfo.forceUpdatePlatform();
    final appBuild = await AppBuildInfo.currentBuildNumber();
    if (platform == null || appBuild == null) return null;

    try {
      final response = await AdPlacementService.fetchPlacement(
        AppConstants.driverForceUpdatePlacementKey,
        platform: platform,
        appBuild: appBuild,
      ).timeout(const Duration(seconds: 10));

      return AdPlacementPayload.fromApiResponse(response);
    } catch (_) {
      return null;
    }
  }

  static Future<void> openStoreListing() async {
    final storeUrl = _activePlacement?.forceUpdateLinkForCurrentPlatform() ??
        _activePlacement?.resolveLinkForPlatform();
    if (storeUrl == null || storeUrl.isEmpty) return;

    if (!kIsWeb && Platform.isAndroid) {
      final marketUri = Uri.parse(
        'market://details?id=${AppConstants.androidPackageName}',
      );
      if (await canLaunchUrl(marketUri)) {
        final launched = await launchUrl(
          marketUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
    }

    final webUri = Uri.parse(storeUrl);
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  static String localizedTitle(AppStrings strings) {
    final custom = _activePlacement?.headline.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return strings.appUpdateRequiredTitle;
  }

  static String localizedMessage(AppStrings strings) {
    final custom = _activePlacement?.supportingCopy.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return strings.appUpdateRequiredMessage;
  }

  static String localizedButtonLabel(AppStrings strings) {
    final custom = _activePlacement?.buttonLabel.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return strings.appUpdateNow;
  }
}

/// Blocks the entire app while [AppUpdateService] has an active force-update
/// placement from the backend.
class AppUpdateBlockingOverlay extends StatelessWidget {
  const AppUpdateBlockingOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdPlacementPayload?>(
      valueListenable: AppUpdateService.placementNotifier,
      builder: (context, placement, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (placement != null) ...[
              const ModalBarrier(
                dismissible: false,
                color: Color(0x73000000),
              ),
              Center(
                child: AppUpdateRequiredCard(
                  placement: placement,
                  onUpdate: AppUpdateService.openStoreListing,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
