import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../config/dashboard_theme.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/app_strings_scope.dart';
import '../../shared/widgets/profile_avatar_image.dart';
import '../../services/location_tracker_service.dart';
import 'home_controller.dart';
import 'models/driver_ride_details.dart';
import 'models/nearby_ride_offer.dart';
import 'ride_completed_view.dart';
import '../../routes/app_routes.dart';
import 'widgets/active_pickup_panel.dart';
import 'widgets/active_trip_panel.dart';
import 'widgets/cancel_trip_modal.dart';
import 'widgets/earnings_panel.dart';
import 'widgets/refer_driver_modal.dart';
import 'widgets/arrived_at_added_stop_modal.dart';
import 'widgets/rider_added_stop_modal.dart';
import '../ride/chat/ride_chat_args.dart';
import '../ride/chat/ride_chat_view.dart';
import '../ride/widgets/dial_modal.dart';
import '../../services/ad_placement_service.dart';
import '../../services/auth_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/screen_wake_service.dart';
import '../../utils/driver_auth_navigation.dart';
import '../auth/widgets/auth_top_toast.dart';
import 'widgets/driver_ad_placement_banner.dart';
import 'widgets/driver_home_ad_modal.dart';
import 'widgets/ride_dashboard_panel.dart';
import 'widgets/ride_request_panel.dart';
import 'widgets/top_up_checkout_view.dart';
import 'widgets/top_up_panel.dart';
import 'widgets/withdrawal_panel.dart';
import '../ride/call/in_app_call_args.dart';
import '../tutorial/app_tutorial_replay.dart';
import '../tutorial/tutorial_screen_helper.dart';
import '../tutorial/tutorial_target.dart';
import '../tutorial/tutorial_target_registry.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key, this.showMap = true});

  final bool showMap;

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with WidgetsBindingObserver {
  final _tutorialRegistry = TutorialTargetRegistry();
  HomeController get _controller => ref.read(homeControllerProvider);
  Timer? _homeAdPollTimer;
  var _isShowingRiderStopModal = false;
  var _isShowingAddedStopArrivalModal = false;
  var _isShowingHomeAdModal = false;
  String? _shownRiderStopNotificationKey;
  String? _shownAddedStopArrivalKey;
  String? _shownHomeAdKey;
  DateTime? _lastLocationErrorToastAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ScreenWakeService.enable());
    _controller.addListener(_onControllerUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Future(() async {
        if (!mounted) return;

        final controller = ref.read(homeControllerProvider);
        controller.processPendingRideNotificationHandlers();
        if (!mounted) return;
        await AuthService.maintainSession();
        if (!mounted) return;
        await controller.restoreActiveRideOnLaunch();
        if (!mounted) return;
        await controller.loadTodayStats();
        if (!mounted) return;
        if (controller.sessionRecoveryRequired) return;
        if (!mounted) return;
        await Future.wait([
          controller.loadDriverProfile(),
          controller.loadReferDriver(),
        ]);
        if (!mounted) return;
        _maybeScheduleHomeTutorial();
      });

      _startHomeAdPolling();
    });
  }

  void _maybeScheduleHomeTutorial() {
    if (_controller.hasActivePickup ||
        _controller.hasRideRequest ||
        _controller.hasActiveTrip) {
      return;
    }

    scheduleTutorialForRoute(
      state: this,
      route: AppRoutes.home,
      registry: _tutorialRegistry,
    );
    AppTutorialReplay.triggerHomeReplayIfPending(
      context: context,
      registry: _tutorialRegistry,
    );
  }

  void _startHomeAdPolling() {
    _homeAdPollTimer?.cancel();
    unawaited(_pollHomeAd());
    _homeAdPollTimer = Timer.periodic(
      AdPlacementCache.homeModalPollInterval,
      (_) => unawaited(_pollHomeAd()),
    );
  }

  bool _canShowHomeAdModal() {
    if (_isShowingHomeAdModal ||
        _isShowingRiderStopModal ||
        _isShowingAddedStopArrivalModal) {
      return false;
    }
    if (!AuthService.isLoggedIn) return false;
    if (_controller.hasActivePickup ||
        _controller.hasActiveTrip ||
        _controller.hasRideRequest ||
        _controller.isPendingRideAcceptance) {
      return false;
    }
    return true;
  }

  Future<void> _pollHomeAd() async {
    if (!mounted || !_canShowHomeAdModal()) return;

    await AdPlacementCache.instance.refreshKey(
      AdPlacementCache.driverTripCompleteKey,
      authenticated: true,
    );

    if (!mounted || !_canShowHomeAdModal()) return;

    final cache = AdPlacementCache.instance;
    if (!cache.hasLoaded(AdPlacementCache.driverTripCompleteKey)) return;

    final placement = cache.get(AdPlacementCache.driverTripCompleteKey);
    if (placement == null) return;

    final adKey = placement.updatedAt.isNotEmpty
        ? placement.updatedAt
        : '${placement.headline}|${placement.creativeImageUrl}';
    if (_shownHomeAdKey == adKey) return;

    _isShowingHomeAdModal = true;
    _shownHomeAdKey = adKey;

    await DriverHomeAdModal.show(context, placement: placement);

    if (mounted) {
      _isShowingHomeAdModal = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(ScreenWakeService.disable());
    _homeAdPollTimer?.cancel();
    _controller.removeListener(_onControllerUpdated);
    _controller.detachMapController();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ScreenWakeService.enable());
      unawaited(
        PushNotificationService.processPendingRideNotificationHandlersOnResume(),
      );
      unawaited(_controller.refreshDashboardOnResume());
    }
  }

  void _onControllerUpdated() {
    if (!mounted) return;

    if (_controller.sessionRecoveryRequired) {
      final strings = AppStringsScope.of(context);
      final message = AuthService.sanitizeAuthErrorMessage(
        _controller.sessionRecoveryMessage ?? strings.sessionExpiredSignInAgain,
      );
      _controller.clearSessionRecoveryRequired();
      AuthTopToast.showError(context, message);
      unawaited(DriverAuthNavigation.redirectToLogin(context));
      return;
    }

    final canShowRiderStopModal = _controller.hasActivePickup ||
        _controller.isPendingRideAcceptance;

    if (!canShowRiderStopModal) {
      _shownRiderStopNotificationKey = null;
    } else if (!_isShowingRiderStopModal) {
      final notification = _controller.pendingRiderStopNotification;
      if (notification != null && notification.stops.isNotEmpty) {
        final key = notification.stops.map((s) => s.key).join('|');
        if (_shownRiderStopNotificationKey != key) {
          _shownRiderStopNotificationKey = key;
          _isShowingRiderStopModal = true;
          unawaited(_showRiderAddedStopModal(notification));
        }
      }
    }

    if (!_controller.hasActiveTrip) {
      _shownAddedStopArrivalKey = null;
    } else if (!_isShowingAddedStopArrivalModal) {
      final arrival = _controller.pendingAddedStopArrival;
      if (arrival != null) {
        final key = arrival.stop.key;
        if (_shownAddedStopArrivalKey != key) {
          _shownAddedStopArrivalKey = key;
          _isShowingAddedStopArrivalModal = true;
          unawaited(_showArrivedAtAddedStopModal(arrival));
        }
      }
    }
  }

  Future<void> _showRiderAddedStopModal(
    RiderStopNotification notification,
  ) async {
    await RiderAddedStopModal.show(
      context,
      notification: notification,
    );
    if (!mounted) return;

    _controller.acknowledgeRiderStopNotification();
    _isShowingRiderStopModal = false;
  }

  Future<void> _showArrivedAtAddedStopModal(
    AddedStopArrivalNotification notification,
  ) async {
    await ArrivedAtAddedStopModal.show(
      context,
      notification: notification,
      onOpenWaze: _controller.openWazeToFinalDestination,
    );
    if (!mounted) return;

    _controller.acknowledgeAddedStopArrival();
    _isShowingAddedStopArrivalModal = false;
  }

  void _showDialModal() {
    final s = AppStringsScope.of(context);
    final offer = _controller.activePickupOffer ?? _controller.currentRideOffer;
    if (offer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noActiveRideToCall)),
      );
      return;
    }

    unawaited(
      DialModal.show(
        context,
        riderName: offer.riderName,
        initialPhoneNumber: offer.riderPhone,
        resolvePhoneNumber: _controller.resolveRiderPhone,
        resolveOnDialPressed: _controller.resolveRiderPhoneOnDial,
        onCallInApp: _openInAppCall,
      ),
    );
  }

  void _openInAppCall() {
    final s = AppStringsScope.of(context);
    final offer = _controller.activePickupOffer ?? _controller.currentRideOffer;
    if (offer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noActiveRideToCall)),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.inAppCall,
      arguments: InAppCallArgs(
        rideId: offer.id,
        counterpartName: offer.riderName ?? s.rider,
        riderPhotoUrl: offer.riderPhotoUrl,
        riderRating: offer.riderRating,
      ),
    );
  }

  void _openRideChat() {
    final s = AppStringsScope.of(context);
    final offer = _controller.activePickupOffer ?? _controller.currentRideOffer;
    if (offer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noActiveRideToChat)),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RideChatView(
          args: RideChatArgs(
            rideId: offer.id,
            riderName: offer.riderName,
            riderPhotoUrl: offer.riderPhotoUrl,
            pickupAddress: offer.pickupAddress,
            riderRating: offer.riderRating,
          ),
        ),
      ),
    );
  }

  void _handleGoOnlinePressed() {
    unawaited(_handleGoOnlinePressedAsync());
  }

  Future<void> _handleGoOnlinePressedAsync() async {
    final error = await _controller.toggleOnlineStatus();
    if (!mounted || error == null) return;
    _showLocationErrorSnackBar(error);
  }

  Future<void> _handleAcceptRide() async {
    final error = await _controller.acceptRideRequest();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _handleIgnoreRide() async {
    final error = await _controller.declineRideRequest();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _handleCompletePickup() async {
    final error = await _controller.completePickup();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _handleCancelRide() async {
    final reason = await CancelTripModal.show(context);
    if (!mounted || reason == null) return;

    final error = await _controller.cancelActiveRideWithReason(reason);
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _openRideCompletedScreen({
    required String rideId,
    required DriverRideDetails initialDetails,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return RideCompletedView(
            rideId: rideId,
            initialDetails: initialDetails,
            onDone: () {
              _controller.dismissRideCompleted();
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }

  Future<void> _handleStartRide() async {
    final error = await _controller.startRide();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _handleOpenWazeToPickup() async {
    final error = await _controller.openWazeToPickup();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _handleCompleteTrip() async {
    final rideId = _controller.activeTripRideIdForCompletion;
    final provisionalDetails = _controller.buildProvisionalCompletionDetails();
    if (rideId == null || provisionalDetails == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStringsScope.of(context).errNoActiveTripComplete),
        ),
      );
      return;
    }

    var completionScreenOpen = true;
    unawaited(
      _openRideCompletedScreen(
        rideId: rideId,
        initialDetails: provisionalDetails,
      ).whenComplete(() {
        completionScreenOpen = false;
      }),
    );

    final error = await _controller.completeTrip();
    if (!mounted) return;
    if (error == null) return;

    if (completionScreenOpen) {
      Navigator.of(context).pop();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _handleOpenWazeToDropoff() async {
    final error = await _controller.openWazeToDropoff();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _handleCenterOnUser() async {
    final result = await _controller.centerOnUser(forceRefresh: true);
    if (!mounted || result.isOk) return;

    final s = AppStringsScope.of(context);
    _showLocationErrorSnackBar(
      result.error!,
      settingsAction: result.settingsAction,
      settingsLabel: s.settings,
    );
  }

  void _showLocationErrorSnackBar(
    String message, {
    LocationSettingsAction? settingsAction,
    String? settingsLabel,
  }) {
    final now = DateTime.now();
    final last = _lastLocationErrorToastAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastLocationErrorToastAt = now;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: settingsAction == null || settingsLabel == null
            ? null
            : SnackBarAction(
                label: settingsLabel,
                onPressed: () {
                  switch (settingsAction) {
                    case LocationSettingsAction.appSettings:
                      unawaited(Geolocator.openAppSettings());
                    case LocationSettingsAction.locationServices:
                      unawaited(Geolocator.openLocationSettings());
                  }
                },
              ),
      ),
    );
  }

  Future<void> _handleTopUp(double amount) async {
    await _controller.loadDriverProfile();

    final validationError = _controller.validateTopUpAmount(amount);
    if (!mounted) return;
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    final args = await _controller.prepareTopUpCheckout(amount);
    if (!mounted) return;
    if (args == null) {
      final s = AppStringsScope.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.couldNotStartTopUp),
        ),
      );
      return;
    }

    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TopUpCheckoutView(args: args),
      ),
    );

    if (!mounted) return;
    if (success == true) {
      await _controller.refreshEarnings();
      if (!mounted) return;
      _controller.closeTopUp();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStringsScope.of(context).walletToppedUp)),
      );
      return;
    }

    if (success == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStringsScope.of(context).topUpCancelled)),
      );
    }
  }

  Future<void> _handleWithdrawal({
    required double amount,
    required String bankAccountName,
    required String bankName,
    required String iban,
    required String accountNumber,
  }) async {
    final (result, error) = await _controller.submitWithdrawal(
      amount: amount,
      bankAccountName: bankAccountName,
      bankName: bankName,
      iban: iban,
      accountNumber: accountNumber,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (result != null) {
      _controller.closeWithdrawal();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _handleRefer() async {
    await _controller.loadReferDriver();
    if (!mounted) return;

    final code = _controller.referralCode?.trim();
    if (code == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStringsScope.of(context).errReferDriverUnavailable),
        ),
      );
      return;
    }

    await ReferDriverModal.show(context, referralCode: code);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(homeControllerProvider);
    final r = context.responsive;
    final showsBottomModal = _controller.showsBottomModal;
    final hasActiveTrip = _controller.hasActiveTrip;
    final hasActiveRide = _controller.hasActiveRide;
    final isDefaultDashboard =
        !showsBottomModal && !hasActiveTrip && !hasActiveRide;
    final isEarningsTab = _controller.selectedTab == DashboardTab.earnings;
    final bottomPanelHeight = r.rideDashboardPanelHeight(
      activeTrip: hasActiveTrip,
      activeRide: hasActiveRide,
      earningsTab: isEarningsTab && isDefaultDashboard,
    );
    final modalBottomInset =
        r.ridePanelHorizontalInset + r.viewPadding.bottom;
    final mapBottomInset = showsBottomModal
        ? 0.0
        : bottomPanelHeight - r.h(36);
    final modalHeightEstimate = r.rideModalMaxHeight(
      activePickup: _controller.hasActivePickup,
    );
    final locationButtonBottom = r.locationButtonBottomOffset(
      showsBottomModal: showsBottomModal,
      modalHeightEstimate: modalHeightEstimate,
      modalBottomInset: modalBottomInset,
      activePanelHeight: bottomPanelHeight,
      isDefaultDashboard: isDefaultDashboard,
    );
    final panelMaxWidth =
        r.isTablet ? r.maxContentWidth : double.infinity;

    return Scaffold(
      backgroundColor: DashboardTheme.of(context).scaffold,
      resizeToAvoidBottomInset: !(
        _controller.showsTopUp || _controller.showsWithdrawal
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: mapBottomInset,
            child: _MapSection(showMap: widget.showMap),
          ),
          Positioned(
            right: r.gap(16),
            bottom: locationButtonBottom,
            child: TutorialTarget(
              registry: _tutorialRegistry,
              id: 'home_location',
              child: _LocationButton(
                onPressed: () => unawaited(_handleCenterOnUser()),
              ),
            ),
          ),
          Positioned(
            left: showsBottomModal ? r.ridePanelHorizontalInset : 0,
            right: showsBottomModal ? r.ridePanelHorizontalInset : 0,
            bottom: showsBottomModal ? modalBottomInset : 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: panelMaxWidth,
                  maxHeight: showsBottomModal
                      ? modalHeightEstimate
                      : bottomPanelHeight,
                ),
                child: showsBottomModal
                    ? SingleChildScrollView(
                        child: _buildRidePanelSwitcher(
                          bottomPanelHeight: bottomPanelHeight,
                          hasActiveTrip: hasActiveTrip,
                          hasActiveRide: hasActiveRide,
                        ),
                      )
                    : SizedBox(
                        height: bottomPanelHeight,
                        child: _buildRidePanelSwitcher(
                          bottomPanelHeight: bottomPanelHeight,
                          hasActiveTrip: hasActiveTrip,
                          hasActiveRide: hasActiveRide,
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            top: r.viewPadding.top + r.gap(8),
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.gap(16)),
                  child: _DashboardHeader(
                    isOnline: _controller.isOnline,
                    avatarUrl: _controller.avatarUrl,
                    displayName: _controller.driverFullName,
                    tutorialRegistry: _tutorialRegistry,
                    onProfileTap: () async {
                      await Navigator.of(context).pushNamed(AppRoutes.profile);
                      if (mounted) {
                        unawaited(_controller.loadDriverProfile());
                      }
                    },
                    onNotificationTap: () {
                      Navigator.of(context).pushNamed(AppRoutes.notifications);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRidePanelSwitcher({
    required double bottomPanelHeight,
    required bool hasActiveTrip,
    required bool hasActiveRide,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
      child: _controller.hasActivePickup
              ? ActivePickupPanel(
                  key: ValueKey(
                    _controller.activePickupOffer?.id ?? 'active_pickup',
                  ),
                  offer: _controller.activePickupOffer!,
                  pickupTitle: _controller.activePickupTitle,
                  progress: _controller.pickupProgress,
                  isCompletingPickup: _controller.isCompletingPickup,
                  isCancellingRide: _controller.isCancellingRide,
                  onCancelRide: () => unawaited(_handleCancelRide()),
                  onPickupCompleted: () => unawaited(_handleCompletePickup()),
                  onOpenWithWaze: () => unawaited(_handleOpenWazeToPickup()),
                  onCall: _showDialModal,
                  onMessage: _openRideChat,
                )
              : _controller.hasRideRequest
                  ? RideRequestPanel(
                      key: ValueKey(
                        _controller.displayedRideRequestOffer!.id,
                      ),
                      offer: _controller.displayedRideRequestOffer!,
                      isAccepting: _controller.isAcceptingRide,
                      isDeclining: _controller.isDecliningRide,
                      onIgnore: () => unawaited(_handleIgnoreRide()),
                      onAccept: () => unawaited(_handleAcceptRide()),
                      onExpired: () {
                        if (_controller.isAcceptingRide) return;
                        unawaited(_handleIgnoreRide());
                      },
                    )
                  : hasActiveTrip
                      ? SizedBox(
                          key: const ValueKey('active_trip'),
                          height: bottomPanelHeight,
                          child: ActiveTripPanel(
                            key: ValueKey(
                              _controller.activePickupOffer?.id ?? 'active_trip',
                            ),
                            offer: _controller.activePickupOffer!,
                            progress: _controller.tripProgress,
                            isCompletingTrip: _controller.isCompletingTrip,
                            onCompleteTrip: () => unawaited(_handleCompleteTrip()),
                            onOpenWithWaze: () => unawaited(_handleOpenWazeToDropoff()),
                          ),
                        )
                      : hasActiveRide
                          ? SizedBox(
                              key: const ValueKey('ride_dashboard'),
                              height: bottomPanelHeight,
                              child: RideDashboardPanel(
                                offer: _controller.activePickupOffer!,
                                isOnline: _controller.isOnline,
                                isUpdatingOnlineStatus:
                                    _controller.isUpdatingOnlineStatus,
                                onGoOnlinePressed: _handleGoOnlinePressed,
                                isCancellingRide: _controller.isCancellingRide,
                                isStartingRide: _controller.isStartingRide,
                                onCancelRide: () => unawaited(_handleCancelRide()),
                                onStartRide: () => unawaited(_handleStartRide()),
                                onCall: _showDialModal,
                                onMessage: _openRideChat,
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('dashboard'),
                              height: bottomPanelHeight,
                              child: _DashboardPanel(
                                controller: _controller,
                                isOnline: _controller.isOnline,
                                isUpdatingOnlineStatus:
                                    _controller.isUpdatingOnlineStatus,
                                onGoOnlinePressed: _handleGoOnlinePressed,
                                onTopUp: _handleTopUp,
                                onWithdraw: _handleWithdrawal,
                                onRefer: () => unawaited(_handleRefer()),
                                tutorialRegistry: _tutorialRegistry,
                              ),
                            ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.isOnline,
    required this.onProfileTap,
    required this.onNotificationTap,
    required this.tutorialRegistry,
    this.avatarUrl,
    this.displayName,
  });

  final bool isOnline;
  final String? avatarUrl;
  final String? displayName;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationTap;
  final TutorialTargetRegistry tutorialRegistry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final avatarSize = r.w(48).clamp(42.0, 56.0);
    final dashboard = DashboardTheme.of(context);

    return Row(
      children: [
        TutorialTarget(
          registry: tutorialRegistry,
          id: 'home_profile',
          child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onProfileTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.loginButton, width: 2),
              ),
              child: ClipOval(
                child: ProfileAvatarImage(
                  size: avatarSize,
                  avatarUrl: avatarUrl,
                  displayName: displayName,
                ),
              ),
            ),
          ),
        ),
        ),
        Expanded(
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.gap(14),
                vertical: r.gap(8),
              ),
              decoration: BoxDecoration(
                color: dashboard.headerPill,
                borderRadius: BorderRadius.circular(r.gap(10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dashboard.isDark ? 0.35 : 0.08),
                    blurRadius: r.gap(10),
                    offset: Offset(0, r.gap(2)),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: r.w(8),
                    height: r.w(8),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: r.gap(8)),
                  Text(
                    isOnline ? s.youAreOnline : s.youAreOffline,
                    style: TextStyle(
                      fontFamily: AppFonts.plusJakartaSans,
                      fontSize: r.captionSize,
                      fontWeight: FontWeight.w600,
                      color: dashboard.headerPillText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        TutorialTarget(
          registry: tutorialRegistry,
          id: 'home_notifications',
          child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onNotificationTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: dashboard.iconButton,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dashboard.isDark ? 0.35 : 0.08),
                    blurRadius: r.gap(10),
                    offset: Offset(0, r.gap(2)),
                  ),
                ],
              ),
              child: Center(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    dashboard.notificationIcon,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    AppConstants.notificationIconAsset,
                    width: avatarSize * 0.32,
                    height: avatarSize * 0.32,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        ),
      ],
    );
  }
}

class _MapSection extends ConsumerWidget {
  const _MapSection({required this.showMap});

  final bool showMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(homeControllerProvider);
    final dashboard = DashboardTheme.of(context);

    if (!showMap) {
      return ColoredBox(color: dashboard.mapFallback);
    }

    return GoogleMap(
      key: ValueKey('home_map_${controller.mapSessionId}'),
      initialCameraPosition: CameraPosition(
        target: controller.cameraTarget,
        zoom: controller.hasActiveTrip ? 18 : 16,
      ),
      onMapCreated: controller.attachMapController,
      markers: controller.markers,
      polylines: controller.polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      liteModeEnabled: false,
      minMaxZoomPreference: controller.hasActiveTrip
          ? const MinMaxZoomPreference(17, 20)
          : MinMaxZoomPreference.unbounded,
      style: dashboard.isDark ? DashboardTheme.darkMapStyle : null,
    );
  }
}

class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final size = r.w(48).clamp(42.0, 54.0);

    return Material(
      color: DashboardTheme.of(context).locationButton,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.my_location_rounded,
            color: AppColors.loginButton,
            size: r.iconMd,
          ),
        ),
      ),
    );
  }
}

class _GoOnlineButton extends StatelessWidget {
  const _GoOnlineButton({
    required this.isOnline,
    required this.onPressed,
    this.isLoading = false,
  });

  final bool isOnline;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);

    final buttonColor =
        isOnline ? AppColors.goOfflineButton : AppColors.loginButton;

    return Material(
      color: buttonColor.withValues(alpha: isLoading ? 0.7 : 1),
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: buttonColor.withValues(alpha: 0.45),
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                if (isLoading) return;
                onPressed!();
              },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: r.h(10)),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: r.sp(20).clamp(18.0, 22.0),
                  height: r.sp(20).clamp(18.0, 22.0),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  isOnline ? s.goOffline : s.goOnline,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 16.0),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.controller,
    required this.isOnline,
    required this.isUpdatingOnlineStatus,
    required this.onGoOnlinePressed,
    required this.onTopUp,
    required this.onWithdraw,
    required this.onRefer,
    required this.tutorialRegistry,
  });

  final HomeController controller;
  final bool isOnline;
  final bool isUpdatingOnlineStatus;
  final VoidCallback onGoOnlinePressed;
  final Future<void> Function(double amount) onTopUp;
  final Future<void> Function({
    required double amount,
    required String bankAccountName,
    required String bankName,
    required String iban,
    required String accountNumber,
  }) onWithdraw;
  final VoidCallback onRefer;
  final TutorialTargetRegistry tutorialRegistry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);
    final isEarnings = controller.selectedTab == DashboardTab.earnings;
    final dashboard = DashboardTheme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned.fill(
          child: isEarnings
              ? Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    dashboard.panelImage(AppConstants.dashboardPanelAsset),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: r.dashboardNotchClearance(),
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: dashboard.earningsGradient,
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : dashboard.panelImage(AppConstants.dashboardPanelAsset),
        ),
        Positioned.fill(
          child: isEarnings
              ? Padding(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    r.h(24),
                    0,
                    r.gap(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: r.gap(16)),
                        child: controller.showsEarningsFlow
                            ? _EarningsFlowNavHeader(
                                controller: controller,
                                title: controller.showsTopUp
                                    ? s.topUp
                                    : s.withdraw,
                                onEarningsTap: controller.closeEarningsFlow,
                              )
                            : _DashboardTabs(
                                selectedTab: controller.selectedTab,
                                onTabSelected: controller.selectTab,
                                tutorialRegistry: tutorialRegistry,
                              ),
                      ),
                      SizedBox(height: r.gap(14)),
                      Expanded(
                        child: controller.showsTopUp
                            ? TopUpPanel(
                                isLoading: controller.isLoadingWalletBalance,
                                isProcessingTopUp: controller.isProcessingTopUp,
                                currentBalance:
                                    controller.walletBalance?.primaryBalance ?? 0,
                                onTopUp: onTopUp,
                              )
                            : controller.showsWithdrawal
                                ? WithdrawalPanel(
                                    isLoading: controller.isLoadingWalletBalance,
                                    isProcessingWithdrawal:
                                        controller.isProcessingWithdrawal,
                                    availableBalance: controller
                                            .walletBalance?.availableBalance ??
                                        0,
                                    onWithdraw: onWithdraw,
                                  )
                                : EarningsPanel(
                                    isLoading: controller.isLoadingWalletBalance,
                                    isLoadingSignupBonus:
                                        controller.isLoadingSignupBonus,
                                    isLoadingReferDriver:
                                        controller.isLoadingReferDriver,
                                    isReferEnabled: !controller.isLoadingReferDriver,
                                    wallet: controller.walletBalance,
                                    signupPerformanceBonus:
                                        controller.signupPerformanceBonus,
                                    completedTrips: controller.completedTrips,
                                    isLoadingCompletedTrips:
                                        controller.isLoadingCompletedTrips,
                                    completedTripsCurrentPage:
                                        controller.completedTripsCurrentPage,
                                    completedTripsTotalPages:
                                        controller.completedTripsTotalPages,
                                    canGoToPreviousTripsPage: controller
                                        .canGoToPreviousCompletedTripsPage,
                                    completedTripsHasMore:
                                        controller.completedTripsHasMore,
                                    onNextTripsPage: () => unawaited(
                                      controller.nextCompletedTripsPage(),
                                    ),
                                    onPreviousTripsPage: () => unawaited(
                                      controller.previousCompletedTripsPage(),
                                    ),
                                    onRefresh: controller.refreshEarnings,
                                    onTopUp: controller.openTopUp,
                                    onWithdrawal: controller.openWithdrawal,
                                    onRefer: onRefer,
                                  ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    r.gap(16),
                    r.h(24),
                    r.gap(16),
                    r.gap(10),
                  ),
                  child: Column(
                    children: [
                      _DashboardTabs(
                        selectedTab: controller.selectedTab,
                        onTabSelected: controller.selectTab,
                        tutorialRegistry: tutorialRegistry,
                      ),
                      SizedBox(height: r.gap(14)),
                      const DriverAdPlacementBanner(),
                      SizedBox(height: r.gap(20)),
                      controller.isLoadingTodayStats
                          ? const _LazyStatsBar()
                          : TutorialTarget(
                              registry: tutorialRegistry,
                              id: 'home_dashboard',
                              child: _StatsBar(
                              earnings: controller.todayEarningsDisplay,
                              timeOnline: controller.todayTimeOnlineDisplay,
                              totalRides: controller.todayRidesDisplay,
                              ),
                            ),
                    ],
                  ),
                ),
        ),
        if (!isEarnings)
          Positioned(
            top: r.goOnlineNotchTop(),
            left: 0,
            right: 0,
              child: Center(
                child: SizedBox(
                width: r.w(136).clamp(124.0, 156.0),
                child: TutorialTarget(
                  registry: tutorialRegistry,
                  id: 'home_go_online',
                  child: _GoOnlineButton(
                  isOnline: isOnline,
                  isLoading: isUpdatingOnlineStatus,
                  onPressed: onGoOnlinePressed,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EarningsFlowNavHeader extends StatelessWidget {
  const _EarningsFlowNavHeader({
    required this.controller,
    required this.title,
    required this.onEarningsTap,
  });

  final HomeController controller;
  final String title;
  final VoidCallback onEarningsTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.gap(20)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DashboardTabItem(
                label: s.driver,
                iconAsset: AppConstants.driverTabIconAsset,
                isSelected: false,
                onTap: () => controller.selectTab(DashboardTab.driver),
              ),
              _DashboardTabItem(
                label: s.earnings,
                iconAsset: AppConstants.earningsTabIconAsset,
                isSelected: true,
                onTap: onEarningsTap,
              ),
            ],
          ),
          Center(
            child: Transform.translate(
              offset: Offset(-r.gap(7), r.gap(17)),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(15).clamp(14.0, 16.0),
                  fontWeight: FontWeight.w700,
                  color: AppColors.loginButton,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTabs extends StatelessWidget {
  const _DashboardTabs({
    required this.selectedTab,
    required this.onTabSelected,
    this.tutorialRegistry,
  });

  final DashboardTab selectedTab;
  final ValueChanged<DashboardTab> onTabSelected;
  final TutorialTargetRegistry? tutorialRegistry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final s = AppStringsScope.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.gap(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _DashboardTabItem(
            label: s.driver,
            iconAsset: AppConstants.driverTabIconAsset,
            isSelected: selectedTab == DashboardTab.driver,
            onTap: () => onTabSelected(DashboardTab.driver),
          ),
          TutorialTarget(
            registry: tutorialRegistry ?? TutorialTargetRegistry(),
            id: 'home_earnings_tab',
            child: _DashboardTabItem(
            label: s.earnings,
            iconAsset: AppConstants.earningsTabIconAsset,
            isSelected: selectedTab == DashboardTab.earnings,
            onTap: () => onTabSelected(DashboardTab.earnings),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTabItem extends StatelessWidget {
  const _DashboardTabItem({
    required this.label,
    required this.iconAsset,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final color = isSelected
        ? AppColors.loginButton
        : dashboard.inactiveTab;
    final iconSize = r.iconMd;

    Widget icon = Image.asset(
      iconAsset,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
    );

    if (isSelected) {
      icon = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          AppColors.loginButton,
          BlendMode.srcIn,
        ),
        child: icon,
      );
    } else {
      icon = ColorFiltered(
        colorFilter: ColorFilter.mode(
          dashboard.inactiveTab,
          BlendMode.srcIn,
        ),
        child: icon,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.gap(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          icon,
          SizedBox(height: r.gap(4)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.captionSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LazyStatsBar extends StatefulWidget {
  const _LazyStatsBar();

  @override
  State<_LazyStatsBar> createState() => _LazyStatsBarState();
}

class _LazyStatsBarState extends State<_LazyStatsBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: r.gap(12),
            vertical: r.gap(14),
          ),
          decoration: BoxDecoration(
            color: dashboard.card,
            borderRadius: BorderRadius.circular(r.borderRadiusMd),
          ),
          child: Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Column(
                  children: [
                    _LazyStatsPlaceholder(
                      opacity: opacity,
                      color: dashboard.secondaryText,
                      height: r.sp(10).clamp(9.0, 11.0),
                      width: r.w(52).clamp(44.0, 60.0),
                    ),
                    SizedBox(height: r.gap(8)),
                    _LazyStatsPlaceholder(
                      opacity: opacity,
                      color: dashboard.statValue,
                      height: r.sp(16).clamp(14.0, 18.0),
                      width: r.w(40).clamp(32.0, 48.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LazyStatsPlaceholder extends StatelessWidget {
  const _LazyStatsPlaceholder({
    required this.opacity,
    required this.color,
    required this.height,
    required this.width,
    this.borderRadius = 999,
  });

  final double opacity;
  final Color color;
  final double height;
  final double width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.earnings,
    required this.timeOnline,
    required this.totalRides,
  });

  final String earnings;
  final String timeOnline;
  final String totalRides;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final s = AppStringsScope.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: r.gap(12),
        vertical: r.gap(14),
      ),
      decoration: BoxDecoration(
        color: dashboard.card,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: s.totalEarnings,
              value: earnings,
              labelColor: dashboard.secondaryText,
              valueColor: dashboard.statValue,
            ),
          ),
          Expanded(
            child: _StatItem(
              label: s.timeOnline,
              value: timeOnline,
              labelColor: dashboard.secondaryText,
              valueColor: dashboard.statValue,
            ),
          ),
          Expanded(
            child: _StatItem(
              label: s.totalRides,
              value: totalRides,
              labelColor: dashboard.secondaryText,
              valueColor: dashboard.statValue,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(11).clamp(10.0, 12.0),
            color: labelColor,
          ),
        ),
        SizedBox(height: r.gap(4)),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(16).clamp(14.0, 18.0),
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
