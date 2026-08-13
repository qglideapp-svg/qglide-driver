import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/api_config.dart';
import '../../config/app_constants.dart';
import '../../config/app_strings.dart';
import '../../services/active_ride_storage.dart';
import '../../services/added_stop_arrival_sound_service.dart';
import '../../services/auth_service.dart';
import '../../services/declined_ride_storage.dart';
import '../../services/directions_service.dart';
import '../../services/driver_online_foreground_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/ride_realtime_service.dart';
import '../../services/ride_request_sound_service.dart';
import '../../services/location_tracker_service.dart';
import '../../services/waze_navigation_service.dart';
import 'models/deposit_payment.dart';
import 'models/driver_completed_trip.dart';
import 'models/driver_ride_details.dart';
import 'models/driver_wallet_balance.dart';
import 'models/driver_withdrawal_result.dart';
import 'models/nearby_ride_offer.dart';
import 'models/signup_performance_bonus.dart';
import 'utils/ride_route_progress.dart';
import 'widgets/map_marker_icons.dart';

enum DashboardTab { driver, earnings }

class HomeController extends ChangeNotifier {
  static const defaultPosition = LatLng(25.2854, 51.5310);
  static const _routeColor = Color(0xFFE3AA00);

  HomeController() {
    PushNotificationService.onRideRequestNotificationOpened =
        handleRideRequestNotificationOpened;
    PushNotificationService.onRideRequestNotificationAction =
        handleRideRequestNotificationAction;
    PushNotificationService.onRideCancelledNotification =
        handleRideCancelledNotification;
  }

  /// Processes any ride-request notification payloads/actions once Home is mounted.
  Future<void> processPendingRideNotificationHandlers() async {
    await _ensureDeclinedRideIdsLoaded();
    await PushNotificationService.processPendingRideRequestOpen();
    PushNotificationService.processPendingRideRequestAction();
  }

  Future<void> _ensureDeclinedRideIdsLoaded() async {
    if (_declinedRideIdsLoaded) return;
    _declinedRideIds.addAll(await DeclinedRideStorage.loadActiveIds());
    _declinedRideIdsLoaded = true;
  }

  bool _wasRideDeclined(String? rideId) {
    if (rideId == null || rideId.isEmpty) return false;
    return _declinedRideIds.contains(rideId);
  }

  Future<void> _rememberDeclinedRide(String rideId) async {
    final normalized = rideId.trim();
    if (normalized.isEmpty) return;
    _declinedRideIds.add(normalized);
    _declinedRideIdsLoaded = true;
    await DeclinedRideStorage.remember(normalized);
    PushNotificationService.clearPendingRideRequestLaunchState(
      rideId: normalized,
    );
  }

  var _isOnline = false;
  var _isUpdatingOnlineStatus = false;
  var _hasSyncedOnlineFromStats = false;
  var _isLoadingTodayStats = true;
  var _isRefreshingDashboard = false;
  var _hasLoadedDashboardStats = false;
  var _sessionRecoveryRequired = false;
  String? _sessionRecoveryMessage;
  var _isLoadingSignupBonus = false;
  SignupPerformanceBonus? _signupPerformanceBonus;
  var _isLoadingWalletBalance = false;
  double? _todayEarningsAmount;
  int? _todayTimeOnlineSeconds;
  String _todayRidesDisplay = '--';
  DriverWalletBalance? _walletBalance;
  static const completedTripsPageSize = 4;
  static const addedStopArrivalRadiusMeters = 120.0;
  var _completedTripsOffset = 0;
  var _isLoadingCompletedTrips = false;
  List<DriverCompletedTrip> _completedTrips = const [];
  var _completedTripsTotalCount = 0;
  var _completedTripsHasMore = false;
  var _hasLoadedEarnings = false;
  var _referralStateLoaded = false;
  var _isProcessingTopUp = false;
  var _isProcessingWithdrawal = false;
  String _driverEmail = '';
  String _driverPhone = '';
  String _driverCountryCode = ApiConfig.defaultCountryCode;
  String? _avatarUrl;
  String _driverFullName = '';
  var _selectedTab = DashboardTab.driver;
  GoogleMapController? _mapController;
  LatLng? _pendingCameraTarget;
  var _pendingCameraZoom = 16.0;
  var _pendingCameraBearing = 0.0;
  var _pendingNavigationCamera = false;
  var _mapSessionId = 0;
  DateTime? _lastMapSurfaceRefreshAt;
  DateTime? _homeEntryAt;
  var _isInitializingHomeMap = false;
  var _mapSurfaceReady = false;
  DateTime? _lastNavigationCameraUpdate;
  var _cameraTarget = defaultPosition;
  var _driverPosition = defaultPosition;
  var _gpsPosition = defaultPosition;
  var _routeDistanceTraveled = 0.0;
  var _targetRouteDistance = 0.0;
  var _targetHeading = 0.0;
  var _navigationCameraBearing = 0.0;
  var _lastGpsSpeedMps = 0.0;
  LatLng? _lastCameraFollowPosition;
  var _hasDriverMarker = false;
  var _locationReady = false;
  var _locationDenied = false;
  var _hasRideRequest = false;
  /// Protects a notification-opened preview from brief offline side-effects.
  var _openedRideRequestFromNotification = false;
  var _hasActivePickup = false;
  var _hasActiveRide = false;
  var _hasActiveTrip = false;
  String? _lastCompletedRideId;
  DriverRideDetails? _lastCompletedRideDetails;
  var _showsTopUp = false;
  var _showsWithdrawal = false;
  var _showsTransfer = false;
  var _isProcessingTransfer = false;
  static const _locationUpdateIntervalIdle = Duration(seconds: 8);
  static const _locationUpdateIntervalEnRoute = Duration(seconds: 2);
  static const _navigationFollowZoom = 18.0;
  static const _navigationCameraMinInterval = Duration(milliseconds: 2200);
  static const _navigationSmoothInterval = Duration(milliseconds: 50);
  static const _cameraMinMoveMeters = 12.0;
  static const _cameraMinBearingDelta = 8.0;
  static const _cameraMinSpeedMps = 1.5;
  static const _headingMinSpeedMps = 2.0;
  static const _headingMinDeltaDegrees = 10.0;
  static const _routeTargetMinAdvanceMeters = 0.8;
  static const _routeTargetMaxBackwardMeters = 5.0;
  static const _markerNotifyMinMoveMeters = 1.0;
  static const _routeFreezeSpeedMps = 1.8;
  static const _routeFreezeDistanceMeters = 8.0;
  static const _routeDistanceSmoothFactor = 0.22;
  static const _routeDistanceSmoothFactorSlow = 0.12;
  static const _headingSmoothFactor = 0.18;

  Timer? _nearbyRidesPollingTimer;
  Timer? _rideStatusPollingTimer;
  Timer? _pickupEtaTickTimer;
  Timer? _locationUpdateTimer;
  Timer? _navigationSmoothingTimer;
  Duration? _activeLocationTimerInterval;
  int? _lastLivePickupEtaMinutes;
  StreamSubscription<Position>? _positionStreamSubscription;
  final _rideRealtimeService = RideRealtimeService();
  var _isLocationUpdateInFlight = false;
  var _positionStreamEnRoute = false;
  DateTime? _lastBackendLocationPost;
  var _isFetchingNearbyRides = false;
  var _isFetchingRideStatus = false;
  var _isAcceptingRide = false;
  var _isDecliningRide = false;
  var _isCompletingPickup = false;
  var _isCancellingRide = false;
  var _isStartingRide = false;
  var _isCompletingTrip = false;
  var _isPendingRideAcceptance = false;
  String? _pendingAcceptRideId;
  String? _lastAcceptAttemptRideId;
  DateTime? _lastAcceptAttemptAt;
  static const _nearbyMissDismissThreshold = 2;
  String? _missingFromNearbyRideId;
  var _missingFromNearbyCount = 0;
  NearbyRideOffer? _currentRideOffer;
  NearbyRideOffer? _acceptedRideOffer;
  NearbyRideOffer? _persistedRideOffer;
  final _declinedRideIds = <String>{};
  var _declinedRideIdsLoaded = false;

  BitmapDescriptor? _driverCarIcon;
  BitmapDescriptor? _pickupPinIcon;
  var _rideMapIconsReady = false;
  var _driverHeading = 0.0;
  var _pickupLocation = defaultPosition;
  var _destinationLocation = defaultPosition;
  var _pickupLegStartPosition = defaultPosition;
  var _fullRoutePoints = <LatLng>[];
  List<LatLng> _cachedDestinationRoute = const [];
  LatLng? _cachedDestinationLatLng;
  DateTime? _lastPickupRouteRefreshAt;
  LatLng? _lastPickupRouteOrigin;
  var _routeFetchGeneration = 0;
  final _acknowledgedStopKeys = <String>{};
  final _arrivedAtStopKeys = <String>{};
  RiderStopNotification? _pendingRiderStopNotification;
  AddedStopArrivalNotification? _pendingAddedStopArrival;

  bool get isOnline => _isOnline;
  bool get isUpdatingOnlineStatus => _isUpdatingOnlineStatus;
  bool get isLoadingTodayStats => _isLoadingTodayStats;
  bool get sessionRecoveryRequired => _sessionRecoveryRequired;
  String? get sessionRecoveryMessage => _sessionRecoveryMessage;

  void clearSessionRecoveryRequired() {
    if (!_sessionRecoveryRequired) return;
    _sessionRecoveryRequired = false;
    _sessionRecoveryMessage = null;
  }
  bool get isLoadingSignupBonus => _isLoadingSignupBonus;
  SignupPerformanceBonus? get signupPerformanceBonus => _signupPerformanceBonus;
  bool get isLoadingReferDriver => !_referralStateLoaded;
  bool get canShowReferDriver => AuthService.canShowReferDriver;
  String? get referralCode => AuthService.referralCode;
  bool get isLoadingWalletBalance => _isLoadingWalletBalance;
  bool get isProcessingTopUp => _isProcessingTopUp;
  bool get isProcessingWithdrawal => _isProcessingWithdrawal;
  bool get isProcessingTransfer => _isProcessingTransfer;
  DriverWalletBalance? get walletBalance => _walletBalance;
  bool get hasCommissionFunds => _walletBalance?.hasCommissionFunds ?? true;
  bool get isLoadingCompletedTrips => _isLoadingCompletedTrips;
  List<DriverCompletedTrip> get completedTrips => _completedTrips;
  int get completedTripsTotalCount => _completedTripsTotalCount;
  bool get completedTripsHasMore => _completedTripsHasMore;
  bool get canGoToPreviousCompletedTripsPage => _completedTripsOffset > 0;
  int get completedTripsCurrentPage =>
      _completedTripsOffset ~/ completedTripsPageSize + 1;
  int get completedTripsTotalPages {
    if (_completedTripsTotalCount <= 0) return 1;
    return (_completedTripsTotalCount / completedTripsPageSize).ceil();
  }

  String get todayEarningsDisplay {
    if (_todayEarningsAmount != null) {
      final amount = _todayEarningsAmount!;
      final decimals = amount == amount.roundToDouble() ? 0 : 2;
      return AppStrings.current().formatQar(amount, decimals: decimals);
    }
    return '--';
  }
  String get todayTimeOnlineDisplay {
    if (_todayTimeOnlineSeconds != null) {
      return AppStrings.current()
          .formatOnlineDuration(_todayTimeOnlineSeconds!);
    }
    return '--';
  }
  String get todayRidesDisplay => _todayRidesDisplay;
  String? get avatarUrl => _avatarUrl;
  String get driverFullName => _driverFullName;
  NearbyRideOffer? get currentRideOffer => _currentRideOffer;
  NearbyRideOffer? get activePickupOffer => _acceptedRideOffer;
  NearbyRideOffer? get pendingAcceptOffer =>
      _isPendingRideAcceptance ? _acceptedRideOffer : null;
  NearbyRideOffer? get displayedRideRequestOffer =>
      _currentRideOffer ?? pendingAcceptOffer;
  bool get isAcceptingRide => _isAcceptingRide || _isPendingRideAcceptance;
  bool get isDecliningRide => _isDecliningRide;
  bool get isCompletingPickup => _isCompletingPickup;
  bool get isCancellingRide => _isCancellingRide;
  bool get isStartingRide => _isStartingRide;
  bool get isCompletingTrip => _isCompletingTrip;
  bool get isPendingRideAcceptance => _isPendingRideAcceptance;
  bool get hasRideRequest =>
      (_hasRideRequest && _currentRideOffer != null) || _isPendingRideAcceptance;
  bool get hasActivePickup => _hasActivePickup;
  bool get hasActiveRide => _hasActiveRide;
  bool get hasActiveTrip => _hasActiveTrip;

  int? get livePickupEtaMinutes {
    if (!_hasActivePickup) return null;

    final offer = _acceptedRideOffer;
    if (offer == null) return null;

    final pickup = offer.pickupLatLng;
    if (pickup != null && _locationReady) {
      final meters = Geolocator.distanceBetween(
        _driverPosition.latitude,
        _driverPosition.longitude,
        pickup.latitude,
        pickup.longitude,
      );
      return NearbyRideOffer.etaMinutesFromDistanceMeters(meters);
    }

    return offer.effectivePickupEtaMinutes;
  }

  String get activePickupTitle =>
      NearbyRideOffer.pickupTitleForMinutes(livePickupEtaMinutes);

  RiderStopNotification? get pendingRiderStopNotification =>
      _pendingRiderStopNotification;
  AddedStopArrivalNotification? get pendingAddedStopArrival =>
      _pendingAddedStopArrival;
  String? get lastCompletedRideId => _lastCompletedRideId;
  DriverRideDetails? get lastCompletedRideDetails => _lastCompletedRideDetails;
  bool get showsTopUp => _showsTopUp;
  bool get showsWithdrawal => _showsWithdrawal;
  bool get showsTransfer => _showsTransfer;
  bool get showsEarningsFlow =>
      _showsTopUp || _showsWithdrawal || _showsTransfer;
  bool get showsBottomModal => hasRideRequest || _hasActivePickup;
  bool get showsRidePanel => _hasActiveRide || _hasActiveTrip;
  bool get hasAcceptedRide =>
      _hasActivePickup || _hasActiveRide || _hasActiveTrip;

  bool get _shouldShowRiderPickupPin =>
      (_hasActivePickup || _hasActiveRide || _isPendingRideAcceptance) &&
      _riderPickupLatLng != null;

  LatLng? get _riderPickupLatLng =>
      _acceptedRideOffer?.pickupLatLng ?? _currentRideOffer?.pickupLatLng;
  DashboardTab get selectedTab => _selectedTab;
  LatLng get cameraTarget => _cameraTarget;
  bool get locationReady => _locationReady;
  bool get locationDenied => _locationDenied;
  int get mapSessionId => _mapSessionId;
  bool get mapSurfaceReady => _mapSurfaceReady;
  bool get showsDriverPointer =>
      _hasDriverMarker && _driverCarIcon != null;

  double get pickupProgress {
    if (!_hasActivePickup) return 0;

    final end = _acceptedRideOffer?.pickupLatLng ?? _pickupLocation;
    return RideRouteProgress.calculate(
      start: _pickupLegStartPosition,
      end: end,
      current: _driverPosition,
      routePoints: _activeRoutePoints,
    );
  }

  double get tripProgress {
    if (!_hasActiveTrip) return 0;

    final offer = _acceptedRideOffer;
    final end = offer?.hasRiderStopRequest == true &&
            offer?.requestedDropoffLatLng != null
        ? offer!.requestedDropoffLatLng!
        : (offer?.dropoffLatLng ?? _destinationLocation);

    return RideRouteProgress.calculate(
      start: _pickupLocation,
      end: end,
      current: _driverPosition,
      routePoints: _activeRoutePoints,
    );
  }

  Set<Marker> get markers {
    final markers = <Marker>{};

    final driverIcon = _driverCarIcon;
    if (showsDriverPointer && driverIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _driverPosition,
          icon: driverIcon,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _driverHeading,
        ),
      );
    }

    final pickupIcon = _pickupPinIcon;
    final pickupLatLng = _riderPickupLatLng;
    if (_shouldShowRiderPickupPin && pickupIcon != null && pickupLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider_pickup'),
          position: pickupLatLng,
          icon: pickupIcon,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 1,
        ),
      );
    }

    return markers;
  }

  Set<Polyline> get polylines {
    if (!hasAcceptedRide || _fullRoutePoints.length < 2) {
      return {};
    }

    final points = _validatedRoutePoints(_activeRoutePoints);
    if (points.length < 2) {
      return {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('ride_route'),
        points: points,
        color: _routeColor,
        width: 5,
        geodesic: false,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  static bool _isValidCoordinate(LatLng point) {
    if (point.latitude.isNaN || point.longitude.isNaN) return false;
    if (point.latitude.abs() > 90 || point.longitude.abs() > 180) return false;
    return true;
  }

  List<LatLng> _validatedRoutePoints(List<LatLng> points) {
    return points.where(_isValidCoordinate).toList(growable: false);
  }

  List<LatLng> get _activeRoutePoints => _fullRoutePoints;

  Future<bool> ensureCommissionWalletFunded() async {
    if (_walletBalance == null && !_isLoadingWalletBalance) {
      await loadWalletBalance();
    }
    return _walletBalance?.hasCommissionFunds ?? true;
  }

  Future<String?> toggleOnlineStatus() async {
    if (_isUpdatingOnlineStatus) return null;

    final targetStatus = !_isOnline;
    if (targetStatus) {
      final funded = await ensureCommissionWalletFunded();
      if (!funded) {
        return AppStrings.current().commissionWalletRequiredShort;
      }
    }

    final previousStatus = _isOnline;

    _isUpdatingOnlineStatus = true;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);

    double? latitude;
    double? longitude;

    try {
      if (targetStatus) {
        if (_locationReady) {
          latitude = _gpsPosition.latitude;
          longitude = _gpsPosition.longitude;
          _setDriverPosition(LatLng(latitude, longitude), notify: true);
          unawaited(_showDriverPointerAtCurrentLocation());
        } else {
          final locationResult =
              await LocationTrackerService.getCurrentLocation();
          if (!locationResult.isSuccess) {
            return locationResult.error ??
                AppStrings.current().locationRequiredForOnline;
          }
          latitude = locationResult.location!.latitude;
          longitude = locationResult.location!.longitude;
          _setDriverPosition(LatLng(latitude, longitude));
          _locationReady = true;
          _locationDenied = false;
        }
      }

      _isOnline = targetStatus;
      _applyOnlineSideEffects(targetStatus);
      notifyListeners();

      await AuthService.refreshSessionIfNeeded(force: true);

      final response = await AuthService.driverSetStatus(
        isOnline: targetStatus,
        latitude: latitude,
        longitude: longitude,
      );

      if (response['success'] == true) {
        _isOnline =
            AuthService.extractIsOnlineFromResponse(response) ?? targetStatus;
        _hasSyncedOnlineFromStats = true;
        _applyOnlineSideEffects(_isOnline);
        notifyListeners();
        if (_isOnline) {
          unawaited(PushNotificationService.registerTokenIfLoggedIn());
          unawaited(loadWalletBalance());
        }
        unawaited(loadTodayStats());
        return null;
      }

      _isOnline = previousStatus;
      _applyOnlineSideEffects(previousStatus);
      notifyListeners();
      return AuthService.extractErrorMessage(
        response,
        fallback: AppStrings.current().errOnlineStatus,
      );
    } catch (e) {
      _isOnline = previousStatus;
      _applyOnlineSideEffects(previousStatus);
      notifyListeners();
      return AppStrings.current().errOnlineStatus;
    } finally {
      _isUpdatingOnlineStatus = false;
      notifyListeners();
    }
  }

  void _applyOnlineSideEffects(bool isOnline) {
    if (isOnline) {
      startLocationUpdates();
      startNearbyRidesPolling();
      startRideStatusPolling();
      unawaited(DriverOnlineForegroundService.start());
      return;
    }

    stopLocationUpdates();
    stopNearbyRidesPolling();
    stopRideStatusPolling();
    unawaited(DriverOnlineForegroundService.stop());
    if (!_openedRideRequestFromNotification) {
      dismissRideRequest();
    }
  }

  Duration _resolveLocationUpdateInterval() {
    if (hasAcceptedRide || _hasActiveTrip || _isPendingRideAcceptance) {
      return _locationUpdateIntervalEnRoute;
    }
    return _locationUpdateIntervalIdle;
  }

  bool get _isEnRouteForLocation =>
      hasAcceptedRide || _hasActiveTrip || _isPendingRideAcceptance;

  String? get _activeRideIdForLocation {
    if (!_isEnRouteForLocation) return null;
    return _acceptedRideOffer?.id ??
        _pendingAcceptRideId ??
        _persistedRideOffer?.id ??
        _currentRideOffer?.id;
  }

  void startLocationUpdates() {
    if (!_isOnline && !_isEnRouteForLocation) return;

    final enRoute = _isEnRouteForLocation;
    final interval = _resolveLocationUpdateInterval();
    _restartPositionStream(enRoute: enRoute);

    if (_locationUpdateTimer != null &&
        _activeLocationTimerInterval == interval) {
      return;
    }

    _locationUpdateTimer?.cancel();
    _activeLocationTimerInterval = interval;
    unawaited(_postLocationToBackend());

    _locationUpdateTimer = Timer.periodic(interval, (_) async {
      final nextInterval = _resolveLocationUpdateInterval();
      final nextEnRoute = _isEnRouteForLocation;
      if (nextEnRoute != _positionStreamEnRoute || nextInterval != interval) {
        startLocationUpdates();
        return;
      }
      await _postLocationToBackend();
    });
  }

  void stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _activeLocationTimerInterval = null;
    _stopPositionStream();
    _stopNavigationSmoothing();
  }

  void _restartPositionStream({required bool enRoute}) {
    if (_positionStreamSubscription != null && _positionStreamEnRoute == enRoute) {
      return;
    }

    _stopPositionStream();
    _positionStreamEnRoute = enRoute;
    _positionStreamSubscription =
        LocationTrackerService.watchPosition(enRoute: enRoute).listen(
      _onGpsPosition,
      onError: (_) {},
    );
  }

  void _stopPositionStream() {
    unawaited(_positionStreamSubscription?.cancel());
    _positionStreamSubscription = null;
  }

  void _onGpsPosition(Position position) {
    final target = LatLng(position.latitude, position.longitude);
    _gpsPosition = target;
    if (!_locationReady) {
      _locationReady = true;
      _locationDenied = false;
    }
    if (_driverCarIcon == null) {
      unawaited(_showDriverPointerAtCurrentLocation());
    }
    _lastGpsSpeedMps = position.speed >= 0 ? position.speed : 0;
    if (!_shouldSnapToRoute) {
      _applyDeviceHeading(position);
    }
    _setDriverPosition(target, notify: !_shouldSnapToRoute);
    if (_checkAddedStopArrival(_gpsPosition)) {
      notifyListeners();
    }
    _maybeSyncLocationToBackend();
    if (_hasActivePickup && hasAcceptedRide) {
      if (_fullRoutePoints.length < 2) {
        unawaited(_setupRideRoute());
      } else {
        unawaited(_maybeRefreshPickupRoute());
      }
    } else if (_hasActiveTrip && hasAcceptedRide && _fullRoutePoints.length < 2) {
      unawaited(_setupRideRoute());
    }
  }

  void _applyDeviceHeading(Position position) {
    final heading = position.heading;
    if (position.speed < _headingMinSpeedMps ||
        heading < 0 ||
        heading > 360 ||
        heading.isNaN) {
      return;
    }

    final delta = _angleDelta(_driverHeading, heading).abs();
    if (delta < _headingMinDeltaDegrees) return;

    _driverHeading = _lerpAngle(_driverHeading, heading, 0.35);
  }

  void _maybeSyncLocationToBackend() {
    if (!_isOnline && !_isEnRouteForLocation) return;

    final interval = _resolveLocationUpdateInterval();
    final last = _lastBackendLocationPost;
    if (last != null && DateTime.now().difference(last) < interval) {
      return;
    }

    unawaited(_postLocationToBackend());
  }

  Future<void> _postLocationToBackend() async {
    if (_isLocationUpdateInFlight) return;
    if (!_isOnline && !_isEnRouteForLocation) return;

    _isLocationUpdateInFlight = true;
    try {
      final rideId = _activeRideIdForLocation;

      final heading = (_driverHeading % 360 + 360) % 360;

      await AuthService.updateDriverLocation(
        latitude: _gpsPosition.latitude,
        longitude: _gpsPosition.longitude,
        heading: heading,
        isAvailable: _isOnline && !_isEnRouteForLocation,
        rideId: rideId,
      );
      _lastBackendLocationPost = DateTime.now();
    } finally {
      _isLocationUpdateInFlight = false;
    }
  }

  Future<void> loadDriverProfile() async {
    final response = await AuthService.getUserProfile();
    final profile = AuthService.extractUserProfile(response);

    if (profile != null) {
      _avatarUrl = AuthService.extractAvatarUrl(profile);
      _driverFullName = AuthService.extractProfileFullName(profile) ?? '';
      _driverEmail = AuthService.extractProfileEmail(profile) ?? '';
      _driverPhone = AuthService.extractProfilePhone(profile) ?? '';
      _driverCountryCode =
          AuthService.extractProfileCountryCode(profile) ??
              ApiConfig.defaultCountryCode;
    }

    _referralStateLoaded = true;
    notifyListeners();
  }

  String? validateTransferAmount(double amount) {
    final s = AppStrings.current();
    if (amount <= 0) return s.errValidAmount;
    final available = _walletBalance?.availableBalance ?? 0;
    if (amount > available) {
      return s.errAmountExceedsBalance(available.toStringAsFixed(2));
    }
    return null;
  }

  Future<(bool, String?)> submitTransferToCommission(double amount) async {
    _isProcessingTransfer = true;
    notifyListeners();

    try {
      final balanceLoaded = await refreshAvailableBalanceForWithdrawal();
      if (!balanceLoaded) {
        return (false, AppStrings.current().errLoadBalance);
      }

      final validationError = validateTransferAmount(amount);
      if (validationError != null) {
        return (false, validationError);
      }

      final response = await AuthService.transferToCommissionWallet(
        amount: amount,
      );

      if (response['success'] != true) {
        return (
          false,
          AuthService.extractErrorMessage(
            response,
            fallback: AppStrings.current().errTransferToCommission,
          ),
        );
      }

      final wallet = AuthService.extractTransferWalletBalance(response);
      if (wallet != null) {
        _walletBalance = wallet;
      } else {
        await loadWalletBalance();
      }

      notifyListeners();
      return (true, AppStrings.current().transferToCommissionSuccess);
    } finally {
      _isProcessingTransfer = false;
      notifyListeners();
    }
  }

  Future<TopUpCheckoutArgs?> prepareTopUpCheckout(double amount) async {
    if (amount <= 0) return null;

    _isProcessingTopUp = true;
    notifyListeners();

    try {
      if (_driverFullName.isEmpty ||
          _driverEmail.isEmpty ||
          _driverPhone.isEmpty) {
        await loadDriverProfile();
      }

      final customerName =
          _driverFullName.trim().isEmpty
              ? AppStrings.current().driverFallback
              : _driverFullName.trim();
      final email = _driverEmail.trim();
      final mobile = AuthService.normalizeMobileForDeposit(
        countryCode: _driverCountryCode,
        phone: _driverPhone,
      );

      if (email.isEmpty || mobile.isEmpty) {
        return null;
      }

      final response = await AuthService.createDepositIntent(
        orderId: const Uuid().v4(),
        amount: amount,
        customerName: customerName,
        email: email,
        mobile: mobile,
        isTest: kDebugMode,
      );

      final intent = AuthService.extractDepositPaymentIntent(response);
      if (intent == null ||
          intent.checkoutUrl.isEmpty ||
          intent.paymentReference.isEmpty) {
        return null;
      }

      return TopUpCheckoutArgs(
        checkoutUrl: intent.checkoutUrl,
        paymentReference: intent.paymentReference,
        amount: amount,
      );
    } finally {
      _isProcessingTopUp = false;
      notifyListeners();
    }
  }

  String? validateTopUpAmount(double amount) {
    if (amount <= 0) return AppStrings.current().errValidAmount;
    if (_driverEmail.trim().isEmpty || _driverPhone.trim().isEmpty) {
      return AppStrings.current().errTopUpProfileRequired;
    }
    return null;
  }

  Future<bool> refreshAvailableBalanceForWithdrawal() async {
    _isLoadingWalletBalance = true;
    notifyListeners();

    final response = await AuthService.getWalletBalance(
      includeVerified: true,
      includeToday: false,
    );
    final wallet = AuthService.extractWalletBalance(response);

    if (wallet != null) {
      _walletBalance = wallet;
    }

    _isLoadingWalletBalance = false;
    notifyListeners();
    return wallet != null;
  }

  String? validateWithdrawal({
    required double amount,
    required String bankAccountName,
    required String bankName,
    required String iban,
    required String accountNumber,
    required double availableBalance,
  }) {
    final s = AppStrings.current();
    if (amount <= 0) return s.errValidWithdrawalAmount;
    if (amount > availableBalance) {
      return s.errAmountExceedsBalance(availableBalance.toStringAsFixed(2));
    }
    if (bankAccountName.trim().isEmpty) {
      return s.errAccountHolderName;
    }
    if (bankName.trim().isEmpty) return s.errBankName;
    if (iban.trim().isEmpty) return s.errIban;
    if (accountNumber.trim().isEmpty) return s.errAccountNumber;
    return null;
  }

  Future<(DriverWithdrawalResult?, String?)> submitWithdrawal({
    required double amount,
    required String bankAccountName,
    required String bankName,
    required String iban,
    required String accountNumber,
  }) async {
    _isProcessingWithdrawal = true;
    notifyListeners();

    try {
      final balanceLoaded = await refreshAvailableBalanceForWithdrawal();
      final availableBalance = _walletBalance?.availableBalance ?? 0;

      if (!balanceLoaded) {
        return (
          null,
          AppStrings.current().errLoadBalance,
        );
      }

      final validationError = validateWithdrawal(
        amount: amount,
        bankAccountName: bankAccountName,
        bankName: bankName,
        iban: iban,
        accountNumber: accountNumber,
        availableBalance: availableBalance,
      );
      if (validationError != null) {
        return (null, validationError);
      }

      final response = await AuthService.requestDriverPayout(
        amount: amount,
        bankAccountName: bankAccountName.trim(),
        bankName: bankName.trim(),
        iban: iban.trim(),
        accountNumber: accountNumber.trim(),
      );

      if (response['success'] != true) {
        return (
          null,
          AuthService.extractErrorMessage(
            response,
            fallback: AppStrings.current().errWithdrawal,
          ),
        );
      }

      final wallet = AuthService.extractPayoutWalletBalance(response);
      if (wallet != null) {
        _walletBalance = wallet;
      }

      final message = AuthService.extractPayoutSuccessMessage(response) ??
          AppStrings.current().withdrawalSubmitted;

      notifyListeners();
      return (DriverWithdrawalResult(message: message, walletBalance: wallet), null);
    } finally {
      _isProcessingWithdrawal = false;
      notifyListeners();
    }
  }

  Future<void> loadTodayStats() async {
    // Avoid swapping the stats bar for a skeleton when we already have data —
    // that flash was amplifying the online flicker loop.
    final showLoadingPlaceholder = !_hasLoadedDashboardStats;
    if (showLoadingPlaceholder) {
      _isLoadingTodayStats = true;
      notifyListeners();
    }

    try {
      var response = await AuthService.getDriverTodayStats();
      if (!_isSuccessfulStatsResponse(response)) {
        await AuthService.maintainSession();
        response = await AuthService.getDriverTodayStats();
      }

      final today = AuthService.extractTodayStats(response);

      if (today != null) {
        _hasLoadedDashboardStats = true;
        final earnings = today['total_earnings'];
        if (earnings is num) {
          _todayEarningsAmount = earnings.toDouble();
        }

        final rides = today['total_rides'] ?? today['rides_completed'];
        if (rides is num) {
          _todayRidesDisplay = rides.round().toString();
        }

        final timeOnline = today['time_online'];
        if (timeOnline is Map) {
          final totalSeconds = timeOnline['total_seconds'];
          if (totalSeconds is num) {
            _todayTimeOnlineSeconds = totalSeconds.round();
          } else {
            final totalMinutes = timeOnline['total_minutes'];
            if (totalMinutes is num) {
              _todayTimeOnlineSeconds = totalMinutes.round() * 60;
            }
          }
          if (!_hasSyncedOnlineFromStats && !_isUpdatingOnlineStatus) {
            final isCurrentlyOnline = timeOnline['is_currently_online'];
            if (isCurrentlyOnline is bool) {
              _isOnline = isCurrentlyOnline;
              _hasSyncedOnlineFromStats = true;
              _applyOnlineSideEffects(_isOnline);
            }
          }
        }
      } else {
        await _maybeRequireSessionRecovery(response);
      }
    } finally {
      _isLoadingTodayStats = false;
      if (_isOnline && !_isUpdatingOnlineStatus) {
        _applyOnlineSideEffects(true);
      }
      notifyListeners();
    }
  }

  static bool _isSuccessfulStatsResponse(Map<String, dynamic> response) {
    if (response['success'] == true) return true;
    if (response['retryable'] == true) return false;
    if (AuthService.isUnauthorizedResponse(response)) return false;
    final message = AuthService.extractErrorMessage(response).toLowerCase();
    return !message.contains('not logged in') &&
        !message.contains('sign in again') &&
        !message.contains('unauthorized') &&
        !message.contains('session expired');
  }

  Future<void> _maybeRequireSessionRecovery(
    Map<String, dynamic>? response,
  ) async {
    if (response != null && response['retryable'] == true) return;

    if (response != null &&
        AuthService.isAccountBlockedResponse(response)) {
      _sessionRecoveryRequired = true;
      _sessionRecoveryMessage =
          AppStrings.current().accountBlockedContactSupport;
      return;
    }

    final needsRecovery = response?['session_recovery_required'] == true ||
        (response != null && AuthService.isUnauthorizedResponse(response)) ||
        !AuthService.hasValidSession;

    if (!needsRecovery) return;

    if (AuthService.hasValidSession) return;

    await AuthService.maintainSession();
    if (AuthService.hasValidSession) return;

    _sessionRecoveryRequired = true;
    _sessionRecoveryMessage =
        AppStrings.current().sessionExpiredSignInAgain;
  }

  DateTime? _lastDashboardResumeAt;

  /// Refreshes driver tab data after the app returns from a long idle period.
  Future<void> refreshDashboardOnResume() async {
    if (_isRefreshingDashboard) return;

    // Permission dialogs / FGS notification taps briefly pause the app. Debounce
    // so we do not reload stats + avatar in a tight loop while online.
    final now = DateTime.now();
    final last = _lastDashboardResumeAt;
    if (last != null && now.difference(last) < const Duration(seconds: 8)) {
      if (_isOnline || _isEnRouteForLocation) {
        startLocationUpdates();
      }
      if (!_locationReady && !_isInitializingHomeMap) {
        unawaited(initializeLocation());
      }
      unawaited(PushNotificationService.registerTokenIfLoggedIn());
      return;
    }
    _lastDashboardResumeAt = now;
    _hasSyncedOnlineFromStats = false;

    if (!hasAcceptedRide) {
      refreshMapSurfaceOnResume();
    } else {
      await _recoverActiveRideMapSurface();
    }

    _isRefreshingDashboard = true;
    try {
      final sessionOk = await AuthService.maintainSession();
      if (!sessionOk) {
        await _maybeRequireSessionRecovery(null);
        if (_sessionRecoveryRequired) {
          notifyListeners();
          return;
        }
      }

      unawaited(PushNotificationService.registerTokenIfLoggedIn());
      if (_isOnline || _isEnRouteForLocation) {
        startLocationUpdates();
      }
      await Future.wait([
        loadTodayStats(),
        loadDriverProfile(),
        loadReferDriver(),
      ]);
      if (_isOnline || _isEnRouteForLocation) {
        startLocationUpdates();
      }
      if (hasAcceptedRide || _isPendingRideAcceptance) {
        await _fetchRideStatus(allowWhenOffline: true);
      }
    } finally {
      _isRefreshingDashboard = false;
    }
  }

  /// Recreates the native map surface after iOS/Android destroys it in background.
  void refreshMapSurfaceOnResume() {
    if (hasAcceptedRide) return;
    if (_mapController == null) return;
    if (_isWithinHomeEntryGracePeriod) return;

    final now = DateTime.now();
    final last = _lastMapSurfaceRefreshAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastMapSurfaceRefreshAt = now;

    if (_mapController != null) {
      unawaited(_recoverIdleMapSurface());
      return;
    }

    _scheduleMapSurfaceRecreate();
  }

  Future<void> _recoverIdleMapSurface() async {
    if (_mapController == null) {
      _scheduleMapSurfaceRecreate();
      return;
    }

    try {
      await _syncMapCamera(animated: false);
      notifyListeners();
    } on PlatformException {
      _scheduleMapSurfaceRecreate();
    } catch (_) {
      _scheduleMapSurfaceRecreate();
    }
  }

  void _scheduleMapSurfaceRecreate() {
    detachMapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> _recoverActiveRideMapSurface() async {
    final controller = _mapController;
    if (controller == null) {
      notifyListeners();
      return;
    }

    try {
      await _syncMapCamera(animated: false);
      if (_hasActiveTrip) {
        _maybeFollowNavigationCamera(force: true);
      } else {
        await _updateRideMapCamera(animated: false);
      }
    } on PlatformException {
      detachMapController();
      notifyListeners();
    } catch (_) {
      detachMapController();
      notifyListeners();
    }
  }

  Future<void> loadSignupPerformanceBonus() async {
    if (_isLoadingSignupBonus) return;

    _isLoadingSignupBonus = true;
    notifyListeners();

    try {
      final response = await AuthService.getDriverIncentiveProgress();

      _signupPerformanceBonus =
          AuthService.extractSignupPerformanceBonus(response);
      await AuthService.syncReferralFromIncentiveProgress(response);
      _referralStateLoaded = true;
    } finally {
      _isLoadingSignupBonus = false;
      notifyListeners();
    }
  }

  Future<void> loadReferDriver() async {
    _referralStateLoaded = false;
    notifyListeners();

    await AuthService.ensureReferralSynced();

    _referralStateLoaded = true;
    notifyListeners();
  }

  Future<void> loadWalletBalance({bool retry = true}) async {
    if (_isLoadingWalletBalance) {
      await _waitForWalletBalanceLoad();
      if (_walletBalance != null || !retry) return;
    }

    _isLoadingWalletBalance = true;
    notifyListeners();

    try {
      final maxAttempts = retry ? 5 : 1;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (attempt > 0) {
          await AuthService.refreshSessionIfNeeded(force: attempt >= 2);
          await AuthService.maintainSession();
          await Future<void>.delayed(
            Duration(milliseconds: 400 + (attempt * attempt * 350)),
          );
        } else {
          await AuthService.refreshSessionIfNeeded();
        }

        final response = await AuthService.getWalletBalance();
        if (AuthService.isUnauthorizedResponse(response)) {
          await AuthService.maintainSession();
          continue;
        }

        final wallet = AuthService.extractWalletBalance(response);
        if (wallet == null) continue;

        _walletBalance = wallet;
        final today = wallet.today;
        if (today != null) {
          _todayEarningsAmount = today.totalEarnings;
          _todayRidesDisplay = today.ridesCompleted.toString();
        }
        return;
      }
    } finally {
      _isLoadingWalletBalance = false;
      notifyListeners();
    }
  }

  void resetWalletState() {
    _walletBalance = null;
    _hasLoadedEarnings = false;
  }

  void markHomeEntry() {
    _homeEntryAt = DateTime.now();
  }

  bool get _isWithinHomeEntryGracePeriod {
    final entry = _homeEntryAt;
    if (entry == null) return false;
    return DateTime.now().difference(entry) < const Duration(seconds: 10);
  }

  void prepareForHomeEntry({required bool forceRefresh}) {
    markHomeEntry();
    if (forceRefresh) {
      resetWalletState();
    }
  }

  Future<void> _waitForWalletBalanceLoad({
    Duration timeout = const Duration(seconds: 35),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (_isLoadingWalletBalance && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> loadCompletedTrips({int? offset}) async {
    final nextOffset = offset ?? _completedTripsOffset;
    _isLoadingCompletedTrips = true;
    notifyListeners();

    final response = await AuthService.getDriverCompletedTrips(
      limit: completedTripsPageSize,
      offset: nextOffset,
    );
    final result = AuthService.extractCompletedTrips(response);

    if (result != null) {
      _completedTrips = result.trips;
      _completedTripsOffset = result.offset;
      _completedTripsTotalCount = result.totalCount;
      _completedTripsHasMore = result.hasMore;
    }

    _isLoadingCompletedTrips = false;
    notifyListeners();
  }

  Future<void> refreshEarnings() async {
    await Future.wait([
      loadWalletBalance(),
      loadCompletedTrips(offset: 0),
      loadSignupPerformanceBonus(),
      loadDriverProfile(),
      loadReferDriver(),
    ]);
    _hasLoadedEarnings = true;
    notifyListeners();
  }

  Future<void> ensureEarningsLoaded() async {
    unawaited(loadSignupPerformanceBonus());
    unawaited(loadDriverProfile());
    unawaited(loadReferDriver());

    if (_hasLoadedEarnings && _walletBalance != null) return;

    if (_isLoadingWalletBalance) {
      await _waitForWalletBalanceLoad();
    }

    if (_walletBalance == null) {
      await loadWalletBalance();
    }

    if (_walletBalance == null) {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () async {
          if (_walletBalance == null) {
            await loadWalletBalance();
          }
        }),
      );
    }

    if (!_hasLoadedEarnings) {
      if (_isLoadingCompletedTrips) {
        final deadline = DateTime.now().add(const Duration(seconds: 35));
        while (_isLoadingCompletedTrips && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      } else {
        await loadCompletedTrips(offset: 0);
      }
      _hasLoadedEarnings = true;
    }

    notifyListeners();
  }

  Future<void> nextCompletedTripsPage() async {
    if (!_completedTripsHasMore || _isLoadingCompletedTrips) return;
    await loadCompletedTrips(
      offset: _completedTripsOffset + completedTripsPageSize,
    );
  }

  Future<void> previousCompletedTripsPage() async {
    if (!canGoToPreviousCompletedTripsPage || _isLoadingCompletedTrips) {
      return;
    }
    final previousOffset = _completedTripsOffset - completedTripsPageSize;
    await loadCompletedTrips(offset: previousOffset < 0 ? 0 : previousOffset);
  }

  void selectTab(DashboardTab tab) {
    if (_selectedTab == tab &&
        tab == DashboardTab.earnings &&
        showsEarningsFlow) {
      _showsTopUp = false;
      _showsWithdrawal = false;
      _showsTransfer = false;
      notifyListeners();
      return;
    }
    if (_selectedTab == tab) {
      if (tab == DashboardTab.earnings && !showsEarningsFlow) {
        unawaited(ensureEarningsLoaded());
      }
      return;
    }
    _selectedTab = tab;
    if (tab == DashboardTab.driver) {
      _showsTopUp = false;
      _showsWithdrawal = false;
      _showsTransfer = false;
      if (!_hasLoadedDashboardStats || _driverFullName.isEmpty) {
        unawaited(refreshDashboardOnResume());
      }
    } else if (tab == DashboardTab.earnings) {
      unawaited(ensureEarningsLoaded());
    }
    notifyListeners();
  }

  void openTopUp() {
    _selectedTab = DashboardTab.earnings;
    _showsWithdrawal = false;
    _showsTransfer = false;
    _showsTopUp = true;
    unawaited(ensureEarningsLoaded());
    notifyListeners();
  }

  void closeTopUp() {
    _showsTopUp = false;
    unawaited(loadWalletBalance());
    notifyListeners();
  }

  void openWithdrawal() {
    _selectedTab = DashboardTab.earnings;
    _showsTopUp = false;
    _showsTransfer = false;
    _showsWithdrawal = true;
    unawaited(ensureEarningsLoaded());
    notifyListeners();
  }

  void closeWithdrawal() {
    _showsWithdrawal = false;
    unawaited(loadWalletBalance());
    notifyListeners();
  }

  void openTransfer() {
    _selectedTab = DashboardTab.earnings;
    _showsTopUp = false;
    _showsWithdrawal = false;
    _showsTransfer = true;
    unawaited(ensureEarningsLoaded());
    notifyListeners();
  }

  void closeTransfer() {
    _showsTransfer = false;
    unawaited(loadWalletBalance());
    notifyListeners();
  }

  void closeEarningsFlow() {
    _showsTopUp = false;
    _showsWithdrawal = false;
    _showsTransfer = false;
    unawaited(refreshEarnings());
    notifyListeners();
  }

  void startNearbyRidesPolling() {
    if (!_isOnline || hasAcceptedRide) {
      return;
    }

    // Idempotent: loadTodayStats/resume call this often; do not reset the timer.
    if (_nearbyRidesPollingTimer != null) return;

    unawaited(_fetchNearbyRides());
    _nearbyRidesPollingTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_fetchNearbyRides()),
    );
  }

  void stopNearbyRidesPolling() {
    _nearbyRidesPollingTimer?.cancel();
    _nearbyRidesPollingTimer = null;
  }

  Future<void> restoreActiveRideOnLaunch() async {
    await _ensureDeclinedRideIdsLoaded();
    _persistedRideOffer = await ActiveRideStorage.load();
    await _fetchRideStatus(allowWhenOffline: true);
    if (hasAcceptedRide || _isPendingRideAcceptance) {
      startRideStatusPolling();
      if (_isOnline || hasAcceptedRide) {
        startLocationUpdates();
      }
    }
  }

  void _persistAcceptedRide(NearbyRideOffer? offer) {
    if (offer == null) {
      unawaited(ActiveRideStorage.clear());
      return;
    }

    unawaited(ActiveRideStorage.save(offer));
  }

  NearbyRideOffer _mergeOfferWithCachedDetails(NearbyRideOffer offer) {
    return offer.withRetainedDetailsFrom(
      _acceptedRideOffer ?? _currentRideOffer ?? _persistedRideOffer,
    );
  }

  NearbyRideOffer _mergeAcceptedStatusPoll(NearbyRideOffer offer) {
    return offer.withAcceptedStatusPoll(
      _acceptedRideOffer ?? _currentRideOffer ?? _persistedRideOffer,
    );
  }

  void _startPickupEtaTracking(String rideId) {
    _pickupEtaTickTimer?.cancel();
    _lastLivePickupEtaMinutes = livePickupEtaMinutes;
    _pickupEtaTickTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (!_hasActivePickup || _acceptedRideOffer == null) return;
        _maybeNotifyPickupEtaChanged(force: true);
      },
    );

    final token = AuthService.accessToken;
    if (token == null || token.isEmpty) return;

    unawaited(
      _rideRealtimeService.subscribe(
        rideId: rideId,
        accessToken: token,
        onRideUpdated: _applyRideRealtimeUpdate,
      ),
    );
  }

  void _stopPickupEtaTracking() {
    _pickupEtaTickTimer?.cancel();
    _pickupEtaTickTimer = null;
    _lastLivePickupEtaMinutes = null;
    unawaited(_rideRealtimeService.unsubscribe());
  }

  void _maybeNotifyPickupEtaChanged({bool force = false}) {
    if (!_hasActivePickup) {
      _lastLivePickupEtaMinutes = null;
      return;
    }

    final eta = livePickupEtaMinutes;
    if (!force && eta == _lastLivePickupEtaMinutes) return;

    _lastLivePickupEtaMinutes = eta;
    notifyListeners();
  }

  void _applyRideRealtimeUpdate(Map<String, dynamic> ride) {
    if (!_hasActivePickup && !_isPendingRideAcceptance) return;

    final offer = NearbyRideOffer.fromMap(ride);
    if (offer == null) return;
    if (_acceptedRideOffer != null && offer.id != _acceptedRideOffer!.id) {
      return;
    }

    final status = offer.status.toLowerCase();
    if (status != 'accepted') {
      unawaited(_fetchRideStatus());
      return;
    }

    final merged = _mergeAcceptedStatusPoll(offer);
    _acceptedRideOffer = merged;
    _persistAcceptedRide(_acceptedRideOffer);
    notifyListeners();
  }

  void startRideStatusPolling() {
    if (!_isOnline &&
        !_isPendingRideAcceptance &&
        !hasAcceptedRide &&
        !_hasRideRequest) {
      return;
    }

    if (_rideStatusPollingTimer != null) return;

    unawaited(_fetchRideStatus());
    _rideStatusPollingTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_fetchRideStatus()),
    );
  }

  void stopRideStatusPolling() {
    _rideStatusPollingTimer?.cancel();
    _rideStatusPollingTimer = null;
  }

  String? get _rideStatusPollRideId {
    if (_pendingAcceptRideId != null && _pendingAcceptRideId!.isNotEmpty) {
      return _pendingAcceptRideId;
    }
    if (hasAcceptedRide || _isPendingRideAcceptance) {
      return _acceptedRideOffer?.id;
    }
    if (_hasRideRequest) {
      return _currentRideOffer?.id;
    }
    return null;
  }

  Future<void> _fetchRideStatus({bool allowWhenOffline = false}) async {
    if (_isFetchingRideStatus) return;
    if (!allowWhenOffline &&
        !_isOnline &&
        !_isPendingRideAcceptance &&
        !hasAcceptedRide &&
        !_hasRideRequest) {
      return;
    }

    _isFetchingRideStatus = true;
    try {
      final pollRideId = _rideStatusPollRideId;
      final response = await AuthService.getDriverRideStatus(
        rideId: pollRideId,
      );
      final ride = AuthService.extractDriverRideStatus(response);

      if (ride == null) {
        return;
      }

      final shouldNotify = _applyRideStatus(ride);
      if (shouldNotify) {
        notifyListeners();
      }
    } finally {
      _isFetchingRideStatus = false;
    }
  }

  bool _applyRideStatus(Map<String, dynamic> ride) {
    final offer = NearbyRideOffer.fromMap(ride);
    if (offer == null) return false;

    final status = offer.status.toLowerCase();

    if (_isStartedTripStatus(status)) {
      final enteringTrip = !_hasActiveTrip;
      _enterActiveTripPanel(
        _mergeOfferWithCachedDetails(offer),
        prepareMap: enteringTrip && !_rideMapIconsReady,
      );
      return true;
    }

    if (_isArrivedStatus(status)) {
      if (_hasActiveTrip) return false;

      final enteringStartRide = !_hasActiveRide;
      _enterStartRidePanel(
        _mergeOfferWithCachedDetails(offer),
        prepareMap: enteringStartRide && !_rideMapIconsReady,
      );
      return true;
    }

    if (status == 'accepted') {
      if (_hasActiveRide || _hasActiveTrip) return false;

      final merged = _mergeAcceptedStatusPoll(offer);
      final previousOffer = _acceptedRideOffer;
      final enteringPickup = !_hasActivePickup;
      final etaChanged = previousOffer?.effectivePickupEtaMinutes !=
          merged.effectivePickupEtaMinutes;
      _isPendingRideAcceptance = false;
      _pendingAcceptRideId = null;
      _acceptedRideOffer = merged;
      _persistedRideOffer = null;
      _persistAcceptedRide(_acceptedRideOffer);
      _hasRideRequest = false;
      _currentRideOffer = null;
      _hasActivePickup = true;
      _hasActiveRide = false;
      unawaited(RideRequestSoundService.suppressPlayback());
      stopNearbyRidesPolling();
      if (enteringPickup) {
        unawaited(_setupRideRoute());
        _startPickupEtaTracking(merged.id);
        startLocationUpdates();
      }

      final notification = _buildRiderStopNotification(previousOffer, merged) ??
          (enteringPickup ? _buildStopNotificationForOffer(merged) : null);
      if (notification != null) {
        _pendingRiderStopNotification = notification;
      }

      if (enteringPickup) {
        unawaited(_prepareRideMap());
      }
      return enteringPickup || etaChanged || notification != null;
    }

    if (NearbyRideOffer.isTerminalStatus(status)) {
      final requestRideId = _currentRideOffer?.id;
      if (_hasRideRequest &&
          requestRideId != null &&
          requestRideId == offer.id) {
        dismissRideRequest();
        return true;
      }
      if (!hasAcceptedRide && !_isPendingRideAcceptance) return false;
      _resetActiveRideFlow();
      return true;
    }

    return false;
  }

  void acknowledgeRiderStopNotification() {
    for (final stop in _pendingRiderStopNotification?.stops ?? const []) {
      _acknowledgedStopKeys.add(stop.key);
    }
    _pendingRiderStopNotification = null;
    notifyListeners();
  }

  void acknowledgeAddedStopArrival() {
    final stop = _pendingAddedStopArrival?.stop;
    if ( stop != null) {
      _arrivedAtStopKeys.add(stop.key);
    }
    _pendingAddedStopArrival = null;
    unawaited(AddedStopArrivalSoundService.stop());
    notifyListeners();
  }

  bool _checkAddedStopArrival(LatLng position) {
    if (!_hasActiveTrip || _pendingAddedStopArrival != null) return false;

    final offer = _acceptedRideOffer;
    if (offer == null || offer.stops.isEmpty) return false;

    for (final stop in offer.stops) {
      if (_arrivedAtStopKeys.contains(stop.key)) continue;

      final distanceMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        stop.lat,
        stop.lng,
      );
      if (distanceMeters <= addedStopArrivalRadiusMeters) {
        _pendingAddedStopArrival = AddedStopArrivalNotification(
          stop: stop,
          finalDestination: offer.dropoffAddress,
          finalDestinationLatLng: offer.dropoffLatLng,
        );
        return true;
      }
      break;
    }

    return false;
  }

  RiderStopNotification? _buildRiderStopNotification(
    NearbyRideOffer? previous,
    NearbyRideOffer current,
  ) {
    final newStops = _detectNewStops(previous, current);
    if (newStops.isNotEmpty) {
      return RiderStopNotification(
        stops: newStops,
        updatedFare: current.estimatedFare ?? current.requestedFare,
      );
    }

    if (current.hasPendingDropoffChange &&
        previous?.hasPendingDropoffChange != true) {
      final address = current.pendingStopAddress;
      final latLng = current.requestedDropoffLatLng;
      if (address != null || latLng != null) {
        return RiderStopNotification(
          stops: [
            RideStop(
              lat: latLng?.latitude ?? 0,
              lng: latLng?.longitude ?? 0,
              address: address ?? AppStrings.current().newStop,
            ),
          ],
          updatedFare: current.requestedFare ?? current.estimatedFare,
        );
      }
    }

    return null;
  }

  RiderStopNotification? _buildStopNotificationForOffer(NearbyRideOffer offer) {
    if (!offer.hasRiderStopRequest) return null;

    final unacknowledgedStops = offer.stops
        .where((s) => !_acknowledgedStopKeys.contains(s.key))
        .toList();
    if (unacknowledgedStops.isNotEmpty) {
      return RiderStopNotification(
        stops: unacknowledgedStops,
        updatedFare: offer.estimatedFare ?? offer.requestedFare,
      );
    }

    if (offer.hasPendingDropoffChange) {
      final address = offer.pendingStopAddress;
      final latLng = offer.requestedDropoffLatLng;
      if (address != null || latLng != null) {
        final stop = RideStop(
          lat: latLng?.latitude ?? 0,
          lng: latLng?.longitude ?? 0,
          address: address ?? AppStrings.current().newStop,
        );
        if (!_acknowledgedStopKeys.contains(stop.key)) {
          return RiderStopNotification(
            stops: [stop],
            updatedFare: offer.requestedFare ?? offer.estimatedFare,
          );
        }
      }
    }

    return null;
  }

  List<RideStop> _detectNewStops(
    NearbyRideOffer? previous,
    NearbyRideOffer current,
  ) {
    final previousKeys = {
      ...?previous?.stops.map((s) => s.key),
      ..._acknowledgedStopKeys,
    };

    return current.stops
        .where((s) => !previousKeys.contains(s.key))
        .toList();
  }

  bool _isStartedTripStatus(String status) {
    switch (status) {
      case 'started':
      case 'in_progress':
      case 'ongoing':
        return true;
      default:
        return false;
    }
  }

  bool _isArrivedStatus(String status) {
    switch (status) {
      case 'arrived':
      case 'driver_arrived':
      case 'arrived_at_pickup':
      case 'at_pickup':
        return true;
      default:
        return false;
    }
  }

  void _enterActiveTripPanel(
    NearbyRideOffer offer, {
    bool prepareMap = false,
  }) {
    unawaited(RideRequestSoundService.stop());
    _isPendingRideAcceptance = false;
    _pendingAcceptRideId = null;
    _acceptedRideOffer = offer;
    _persistedRideOffer = null;
    _persistAcceptedRide(_acceptedRideOffer);
    _hasRideRequest = false;
    _currentRideOffer = null;
    _hasActivePickup = false;
    _hasActiveRide = false;
    _hasActiveTrip = true;
    _stopPickupEtaTracking();
    stopNearbyRidesPolling();
    startLocationUpdates();
    _showDestinationRouteNow();
    unawaited(_refreshTripRouteIfNeeded());
    _updateNavigationHeading();
    if (prepareMap || !_rideMapIconsReady) {
      unawaited(_prepareRideMap());
    } else {
      unawaited(_updateRideMapCamera(animated: true));
    }
  }

  void _enterStartRidePanel(
    NearbyRideOffer offer, {
    bool prepareMap = false,
  }) {
    unawaited(RideRequestSoundService.stop());
    _isPendingRideAcceptance = false;
    _pendingAcceptRideId = null;
    _acceptedRideOffer = offer;
    _persistedRideOffer = null;
    _persistAcceptedRide(_acceptedRideOffer);
    _hasRideRequest = false;
    _currentRideOffer = null;
    _hasActivePickup = false;
    _hasActiveRide = true;
    _stopPickupEtaTracking();
    stopNearbyRidesPolling();
    startLocationUpdates();
    _showDestinationRouteNow();
    unawaited(_setupRideRoute());
    _updateNavigationHeading();
    if (prepareMap || !_rideMapIconsReady) {
      unawaited(_prepareRideMap());
    } else {
      unawaited(_fitRouteCamera());
    }
  }

  void _resetActiveRideFlow() {
    _isPendingRideAcceptance = false;
    _pendingAcceptRideId = null;
    _hasRideRequest = false;
    _hasActivePickup = false;
    _hasActiveRide = false;
    _hasActiveTrip = false;
    _acceptedRideOffer = null;
    _currentRideOffer = null;
    _persistedRideOffer = null;
    _persistAcceptedRide(null);
    _clearRideRoute();
    _acknowledgedStopKeys.clear();
    _arrivedAtStopKeys.clear();
    _pendingRiderStopNotification = null;
    _pendingAddedStopArrival = null;
    _stopPickupEtaTracking();
    unawaited(AddedStopArrivalSoundService.stop());
    RideRequestSoundService.allowPlayback();
    if (_isOnline) {
      startNearbyRidesPolling();
      startRideStatusPolling();
      startLocationUpdates();
    }
    unawaited(_recenterMapOnDriverAfterLayout(resetBearing: true));
  }

  Future<String?> _cancelActiveRide({required String reason}) async {
    if (_isCancellingRide) return null;

    final rideId = _acceptedRideOffer?.id;
    if (rideId == null || rideId.isEmpty) {
      _resetActiveRideFlow();
      notifyListeners();
      return null;
    }

    _isCancellingRide = true;
    notifyListeners();
    try {
      final response = await AuthService.cancelRide(
        rideId: rideId,
        reason: reason,
      );

      if (response['success'] != true) {
        return AuthService.extractErrorMessage(
          response,
          fallback: AppStrings.current().errCancelRide,
        );
      }

      _resetActiveRideFlow();
      return null;
    } finally {
      _isCancellingRide = false;
      notifyListeners();
    }
  }

  Future<void> _fetchNearbyRides({bool playSound = true}) async {
    if (!_isOnline ||
        hasAcceptedRide ||
        _isAcceptingRide ||
        _isPendingRideAcceptance ||
        _isFetchingNearbyRides) {
      return;
    }

    _isFetchingNearbyRides = true;
    try {
      await _ensureDriverPositionForPolling();

      final response = await AuthService.getNearbyRides(
        driverLat: _driverPosition.latitude,
        driverLng: _driverPosition.longitude,
      );

      final rides = AuthService.extractNearbyRides(response);
      if (rides.isEmpty) {
        if (_hasRideRequest && _currentRideOffer != null) {
          if (_shouldDismissAfterNearbyMiss(_currentRideOffer!.id)) {
            dismissRideRequest();
          }
        }
        return;
      }

      if (_hasRideRequest && _currentRideOffer != null) {
        final currentId = _currentRideOffer!.id;
        Map<String, dynamic>? currentRideMap;
        for (final ride in rides) {
          if (ride['id']?.toString() == currentId) {
            currentRideMap = ride;
            break;
          }
        }

        if (currentRideMap == null) {
          if (_shouldDismissAfterNearbyMiss(currentId)) {
            dismissRideRequest();
          }
          return;
        }

        final currentOffer = NearbyRideOffer.fromMap(currentRideMap);
        if (currentOffer == null || !currentOffer.isPending) {
          dismissRideRequest();
          return;
        }

        _showRideRequest(
          currentOffer.withRetainedDetailsFrom(_currentRideOffer),
        );
        return;
      }

      final offer = NearbyRideOffer.fromMap(rides.first);
      if (offer == null || !offer.isPending || _wasRideDeclined(offer.id)) {
        if (_hasRideRequest) {
          dismissRideRequest();
        }
        return;
      }

      if (hasAcceptedRide || _isAcceptingRide || _isPendingRideAcceptance) {
        return;
      }

      final shouldNotify = !_hasRideRequest ||
          _currentRideOffer?.id != offer.id ||
          _currentRideOffer?.pickupEtaMinutes != offer.pickupEtaMinutes;

      _showRideRequest(offer);

      if (shouldNotify && playSound && !_shouldSuppressRideRequestSound(offer.id)) {
        unawaited(RideRequestSoundService.play(offer.id));
      }
      if (shouldNotify) {
        notifyListeners();
      }
    } finally {
      _isFetchingNearbyRides = false;
    }
  }

  Future<void> _ensureDriverPositionForPolling() async {
    if (_locationReady) return;

    final result = await LocationTrackerService.getCurrentLocation(
      requestPermissionIfNeeded: false,
    );
    if (!result.isSuccess) return;

    _setDriverPosition(
      LatLng(result.location!.latitude, result.location!.longitude),
    );
    _locationReady = true;
    _locationDenied = false;
  }

  void _clearNearbyMissTracking() {
    _missingFromNearbyRideId = null;
    _missingFromNearbyCount = 0;
  }

  bool _shouldDismissAfterNearbyMiss(String rideId) {
    if (_missingFromNearbyRideId != rideId) {
      _missingFromNearbyRideId = rideId;
      _missingFromNearbyCount = 1;
      return false;
    }

    _missingFromNearbyCount++;
    return _missingFromNearbyCount >= _nearbyMissDismissThreshold;
  }

  void _showRideRequest(NearbyRideOffer offer) {
    if (hasAcceptedRide || _isAcceptingRide || _isPendingRideAcceptance) {
      return;
    }
    if (_wasRideDeclined(offer.id)) {
      return;
    }
    if (!hasCommissionFunds) {
      return;
    }

    _clearNearbyMissTracking();

    if (_hasRideRequest && _currentRideOffer?.id == offer.id) {
      final updated = offer.withRetainedDetailsFrom(_currentRideOffer);
      final detailsChanged = _currentRideOffer?.pickupEtaMinutes !=
              updated.pickupEtaMinutes ||
          _currentRideOffer?.pickupAddress != updated.pickupAddress ||
          _currentRideOffer?.dropoffAddress != updated.dropoffAddress;
      _currentRideOffer = updated;
      if (detailsChanged) {
        notifyListeners();
      }
      return;
    }

    _currentRideOffer = offer;
    _hasRideRequest = true;
    notifyListeners();
  }

  /// Opens the accept panel after the driver taps a ride-request notification.
  Future<void> handleRideRequestNotificationOpened(
    Map<String, dynamic> data,
  ) async {
    final rideId = data['ride_id']?.toString();
    await _ensureDeclinedRideIdsLoaded();
    if (_wasRideDeclined(rideId)) {
      PushNotificationService.clearPendingRideRequestLaunchState(rideId: rideId);
      return;
    }

    if (!hasAcceptedRide && !_isAcceptingRide && !_isPendingRideAcceptance) {
      _openedRideRequestFromNotification = true;
    }

    await _refreshRideRequestAfterNotificationOpened(data);
  }

  /// Dismisses a stale ride-request panel when the rider cancels.
  Future<void> handleRideCancelledNotification(
    Map<String, dynamic> data,
  ) async {
    final rideId =
        data['ride_id']?.toString() ?? data['id']?.toString();
    if (rideId == null || rideId.isEmpty) return;

    unawaited(PushNotificationService.stopAllRideRequestAlerts(rideId: rideId));

    if (_hasRideRequest && _currentRideOffer?.id == rideId) {
      dismissRideRequest();
      return;
    }

    if ((_isPendingRideAcceptance && _pendingAcceptRideId == rideId) ||
        (_acceptedRideOffer?.id == rideId &&
            !_hasActiveTrip &&
            !_hasActiveRide)) {
      _resetActiveRideFlow();
      notifyListeners();
      return;
    }

    if (_hasRideRequest) {
      unawaited(_fetchRideStatus(allowWhenOffline: true));
    }
  }

  /// Accepts or declines a ride from a notification action button.
  Future<void> handleRideRequestNotificationAction(
    String action,
    Map<String, dynamic> data,
  ) async {
    final rideId = data['ride_id']?.toString();
    unawaited(
      PushNotificationService.stopAllRideRequestAlerts(rideId: rideId),
    );

    if (rideId == null || rideId.isEmpty) return;

    if (action == AppConstants.rideRequestNotificationActionIgnore) {
      await declineRideRequest(rideIdOverride: rideId);
      return;
    }

    if (action != AppConstants.rideRequestNotificationActionAccept) return;
    if (_isAcceptingRide || _isDecliningRide || hasAcceptedRide) return;

    final persisted = await ActiveRideStorage.load();
    if (persisted != null && persisted.id == rideId) {
      await _syncAcceptedRideFromNotification(persisted);
      return;
    }

    final previewOffer = NearbyRideOffer.fromNotificationData(data);
    if (previewOffer == null || !previewOffer.isPending) {
      await _refreshRideRequestDetails(rideId: rideId);
    }

    if (_currentRideOffer == null || _currentRideOffer!.id != rideId) {
      if (previewOffer != null && previewOffer.isPending) {
        _currentRideOffer = previewOffer;
      } else {
        return;
      }
    }

    await acceptRideRequest();
  }

  Future<void> _syncAcceptedRideFromNotification(NearbyRideOffer offer) async {
    if (hasAcceptedRide || _isPendingRideAcceptance) return;

    stopNearbyRidesPolling();
    await RideRequestSoundService.suppressPlayback();

    _acceptedRideOffer = offer;
    _pendingAcceptRideId = offer.id;
    _isPendingRideAcceptance = true;
    _hasRideRequest = false;
    _currentRideOffer = null;
    _openedRideRequestFromNotification = false;
    _persistAcceptedRide(offer);

    final stopNotification = _buildStopNotificationForOffer(offer);
    if (stopNotification != null) {
      _pendingRiderStopNotification = stopNotification;
    }

    _startPickupEtaTracking(offer.id);
    startRideStatusPolling();
    startLocationUpdates();
    unawaited(_fetchRideStatus(allowWhenOffline: true));
    notifyListeners();
  }

  Future<void> _refreshRideRequestAfterNotificationOpened(
    Map<String, dynamic> data,
  ) async {
    if (!_hasSyncedOnlineFromStats && !_isUpdatingOnlineStatus) {
      unawaited(loadTodayStats());
    } else if (_isOnline) {
      startNearbyRidesPolling();
    }

    await _refreshRideRequestDetails(
      rideId: data['ride_id']?.toString(),
    );
  }

  Future<void> _refreshRideRequestDetails({String? rideId}) async {
    if (hasAcceptedRide ||
        _isAcceptingRide ||
        _isPendingRideAcceptance ||
        _isFetchingNearbyRides) {
      return;
    }
    if (_wasRideDeclined(rideId)) {
      if (_hasRideRequest &&
          (rideId == null || _currentRideOffer?.id == rideId)) {
        dismissRideRequest();
      }
      return;
    }

    _isFetchingNearbyRides = true;
    try {
      await _ensureDriverPositionForPolling();

      final response = await AuthService.getNearbyRides(
        driverLat: _driverPosition.latitude,
        driverLng: _driverPosition.longitude,
      );

      final rides = AuthService.extractNearbyRides(response);
      if (rides.isEmpty) {
        if (_hasRideRequest && rideId == null) {
          dismissRideRequest();
        }
        return;
      }

      Map<String, dynamic>? rideMap;
      if (rideId != null && rideId.isNotEmpty) {
        for (final ride in rides) {
          if (ride['id']?.toString() == rideId) {
            rideMap = ride;
            break;
          }
        }
      }
      rideMap ??= rides.first;

      final offer = NearbyRideOffer.fromMap(rideMap);
      if (offer == null || !offer.isPending) {
        if (_hasRideRequest &&
            (rideId == null || _currentRideOffer?.id == rideId)) {
          dismissRideRequest();
        }
        return;
      }

      if (hasAcceptedRide || _isAcceptingRide || _isPendingRideAcceptance) {
        return;
      }

      _showRideRequest(offer.withRetainedDetailsFrom(_currentRideOffer));
      notifyListeners();
    } finally {
      _isFetchingNearbyRides = false;
    }
  }

  void dismissRideRequest({bool force = false}) {
    if (!force &&
        (_isAcceptingRide || _isDecliningRide || _isPendingRideAcceptance)) {
      return;
    }

    final rideId = _currentRideOffer?.id;
    unawaited(PushNotificationService.stopAllRideRequestAlerts(rideId: rideId));
    _clearNearbyMissTracking();
    _hasRideRequest = false;
    _openedRideRequestFromNotification = false;
    _currentRideOffer = null;
    if (!hasAcceptedRide && !_isPendingRideAcceptance) {
      stopRideStatusPolling();
    }
    notifyListeners();
  }

  Future<String?> declineRideRequest({String? rideIdOverride}) async {
    if (_isAcceptingRide || _isDecliningRide) return null;

    final rideId =
        rideIdOverride ?? _currentRideOffer?.id ?? _pendingAcceptRideId;
    if (rideId == null || rideId.isEmpty) {
      _isPendingRideAcceptance = false;
      _pendingAcceptRideId = null;
      dismissRideRequest();
      return null;
    }

    _isDecliningRide = true;
    notifyListeners();
    String? error;
    try {
      final response =
          await AuthService.rideResponse(rideId: rideId, action: 'decline');
      _isPendingRideAcceptance = false;
      _pendingAcceptRideId = null;
      if (response['success'] == true ||
          AuthService.isRideAlreadyCancelledResponse(response)) {
        await _rememberDeclinedRide(rideId);
        dismissRideRequest(force: true);
        return null;
      }
      error = AuthService.extractErrorMessage(response);
    } finally {
      _isDecliningRide = false;
      notifyListeners();
    }
    return error;
  }

  bool _shouldSuppressRideRequestSound(String rideId) {
    if (_lastAcceptAttemptRideId != rideId || _lastAcceptAttemptAt == null) {
      return false;
    }
    return DateTime.now().difference(_lastAcceptAttemptAt!) <
        const Duration(seconds: 5);
  }

  Future<String?> acceptRideRequest() async {
    final offer = _currentRideOffer;
    if (offer == null || _isAcceptingRide || _isDecliningRide) {
      return AppStrings.current().errNoRideToAccept;
    }

    final funded = await ensureCommissionWalletFunded();
    if (!funded) {
      return AppStrings.current().commissionWalletRequiredShort;
    }

    _lastAcceptAttemptRideId = offer.id;
    _lastAcceptAttemptAt = DateTime.now();
    _isAcceptingRide = true;
    stopNearbyRidesPolling();
    stopRideStatusPolling();
    await RideRequestSoundService.suppressPlayback();
    unawaited(
      PushNotificationService.stopAllRideRequestAlerts(rideId: offer.id),
    );
    notifyListeners();

    try {
      await _ensureDriverPositionForPolling();

      final response = await AuthService.rideResponse(
        rideId: offer.id,
        action: 'accept',
        latitude: _driverPosition.latitude,
        longitude: _driverPosition.longitude,
      );

      if (response['success'] != true) {
        if (AuthService.isRideAlreadyCancelledResponse(response)) {
          dismissRideRequest(force: true);
          if (_isOnline) {
            startNearbyRidesPolling();
          }
          return null;
        }
        if (AuthService.isRideAlreadyAcceptedResponse(response)) {
          final ride = AuthService.extractDriverRideStatus(response);
          final acceptedOffer = ride != null
              ? NearbyRideOffer.fromMap(ride)?.withAcceptedStatusPoll(offer) ??
                  offer
              : offer;
          _acceptedRideOffer = acceptedOffer;
          _pendingAcceptRideId = offer.id;
          _isPendingRideAcceptance = true;
          _hasRideRequest = false;
          _openedRideRequestFromNotification = false;
          _persistAcceptedRide(offer);
          _startPickupEtaTracking(offer.id);
          startRideStatusPolling();
          startLocationUpdates();
          unawaited(_fetchRideStatus());
          return null;
        }
        if (_isOnline) {
          startNearbyRidesPolling();
        }
        unawaited(
          PushNotificationService.stopAllRideRequestAlerts(rideId: offer.id),
        );
        return AuthService.extractErrorMessage(
          response,
          fallback: AppStrings.current().errAcceptRide,
        );
      }

      final ride = AuthService.extractDriverRideStatus(response);
      final acceptedOffer = ride != null
          ? NearbyRideOffer.fromMap(ride)?.withAcceptedStatusPoll(offer) ??
              offer
          : offer;

      _acceptedRideOffer = acceptedOffer;
      _pendingAcceptRideId = offer.id;
      _isPendingRideAcceptance = true;
      _hasRideRequest = false;
      _openedRideRequestFromNotification = false;

      final stopNotification = _buildStopNotificationForOffer(acceptedOffer);
      if (stopNotification != null) {
        _pendingRiderStopNotification = stopNotification;
      }
      _persistAcceptedRide(offer);
      _startPickupEtaTracking(offer.id);
      startRideStatusPolling();
      startLocationUpdates();
      unawaited(_ensureRideMapIcons());
      unawaited(_fetchRideStatus());
      return null;
    } finally {
      _isAcceptingRide = false;
      if (!_isPendingRideAcceptance) {
        RideRequestSoundService.allowPlayback();
        unawaited(
          PushNotificationService.stopAllRideRequestAlerts(rideId: offer.id),
        );
      }
      notifyListeners();
    }
  }

  Future<String?> cancelActiveRideWithReason(String reason) async {
    return _cancelActiveRide(reason: reason);
  }

  Future<String?> completePickup() async {
    if (_isCompletingPickup || _isCancellingRide) {
      return null;
    }

    final rideId = _acceptedRideOffer?.id;
    if (rideId == null || rideId.isEmpty) {
      return AppStrings.current().errNoActiveRidePickup;
    }

    _isCompletingPickup = true;
    notifyListeners();
    try {
      await _ensureDriverPositionForPolling();

      final offer = _acceptedRideOffer;
      if (offer != null) {
        unawaited(_prefetchDestinationRoute(offer));
      }

      final response = await AuthService.driverArrivedPickup(
        rideId: rideId,
        latitude: _driverPosition.latitude,
        longitude: _driverPosition.longitude,
      );

      if (response['success'] != true) {
        return AuthService.extractErrorMessage(
          response,
          fallback: AppStrings.current().errConfirmPickup,
        );
      }

      if (offer == null) {
        return AppStrings.current().errNoActiveRidePickup;
      }

      _enterStartRidePanel(offer);
      return null;
    } finally {
      _isCompletingPickup = false;
      notifyListeners();
    }
  }


  Future<String?> startRide() async {
    if (_isStartingRide || _isCancellingRide) return null;

    final rideId = _acceptedRideOffer?.id;
    if (rideId == null || rideId.isEmpty) {
      return AppStrings.current().errNoActiveRideStart;
    }

    _isStartingRide = true;
    notifyListeners();
    try {
      final response = await AuthService.startRide(rideId: rideId);

      if (response['success'] != true) {
        return AuthService.extractErrorMessage(
          response,
          fallback: AppStrings.current().errStartRide,
        );
      }

      _hasActiveRide = false;
      _hasActiveTrip = true;
      _persistAcceptedRide(_acceptedRideOffer);
      _showDestinationRouteNow();
      _updateNavigationHeading();
      unawaited(_refreshTripRouteIfNeeded());
      unawaited(_updateRideMapCamera(animated: true));
      return null;
    } finally {
      _isStartingRide = false;
      notifyListeners();
    }
  }

  Future<String?> resolveRiderPhone() async {
    final current = _acceptedRideOffer ?? _currentRideOffer;
    final rideId = current?.id;
    if (rideId == null || rideId.isEmpty) {
      return null;
    }

    final response = await AuthService.getDriverRideStatus(rideId: rideId);
    return _applyDriverRideStatusPhone(response, current);
  }

  Future<({Map<String, dynamic> response, String? phone})>
      resolveRiderPhoneOnDial() async {
    final current = _acceptedRideOffer ?? _currentRideOffer;
    final rideId = current?.id;
    if (rideId == null || rideId.isEmpty) {
      return (
        response: {
          'success': false,
          'error': {'message': AppStrings.current().errNoActiveRideFound},
        },
        phone: null,
      );
    }

    final response = await AuthService.getDriverRideStatus(rideId: rideId);
    final phone = _applyDriverRideStatusPhone(response, current);
    return (response: response, phone: phone);
  }

  String? _applyDriverRideStatusPhone(
    Map<String, dynamic> response,
    NearbyRideOffer? current,
  ) {
    final rideId = current?.id;
    if (rideId == null || rideId.isEmpty) {
      return current?.riderPhone;
    }

    final ride = AuthService.extractDriverRideStatus(response);
    if (ride == null) {
      return current?.riderPhone;
    }

    final offer = NearbyRideOffer.fromMap(ride);
    if (offer == null) {
      return current?.riderPhone;
    }

    final merged = offer.withRetainedDetailsFrom(current);
    if (_acceptedRideOffer?.id == rideId) {
      _acceptedRideOffer = merged;
      _persistAcceptedRide(_acceptedRideOffer);
      notifyListeners();
    } else if (_currentRideOffer?.id == rideId) {
      _currentRideOffer = merged;
    }

    return merged.riderPhone ?? current?.riderPhone;
  }

  Future<String?> openWazeToPickup() async {
    final offer = _acceptedRideOffer ?? _currentRideOffer;
    if (offer == null) {
      return AppStrings.current().errNoActiveRideFound;
    }

    return WazeNavigationService.openNavigation(
      coordinates: offer.pickupLatLng,
      address: offer.pickupAddress,
    );
  }

  Future<String?> openWazeToDropoff() async {
    final offer = _acceptedRideOffer ?? _currentRideOffer;
    if (offer == null) {
      return AppStrings.current().errNoActiveRideFound;
    }

    final useRequestedStop = offer.hasRiderStopRequest;

    return WazeNavigationService.openNavigation(
      coordinates: useRequestedStop
          ? (offer.requestedDropoffLatLng ?? offer.dropoffLatLng)
          : offer.dropoffLatLng,
      address: useRequestedStop
          ? (offer.pendingStopAddress ?? offer.dropoffAddress)
          : offer.dropoffAddress,
    );
  }

  Future<String?> openWazeToFinalDestination() async {
    final offer = _acceptedRideOffer ?? _currentRideOffer;
    if (offer == null) {
      return AppStrings.current().errNoActiveRideFound;
    }

    return WazeNavigationService.openNavigation(
      coordinates: offer.dropoffLatLng,
      address: offer.dropoffAddress,
    );
  }

  String? get activeTripRideIdForCompletion {
    if (!_hasActiveTrip) return null;
    final rideId = _acceptedRideOffer?.id;
    if (rideId == null || rideId.isEmpty) return null;
    return rideId;
  }

  DriverRideDetails? buildProvisionalCompletionDetails() {
    final offer = _acceptedRideOffer;
    if (offer == null || !_hasActiveTrip) return null;

    final actualFare = offer.hasRiderStopRequest && offer.requestedFare != null
        ? offer.requestedFare!
        : (offer.estimatedFare ?? 0);

    return DriverRideDetails.fromActiveOffer(offer, amount: actualFare);
  }

  Future<String?> completeTrip() async {
    if (_isCompletingTrip || _isCancellingRide) return null;

    final rideId = _acceptedRideOffer?.id;
    if (rideId == null || rideId.isEmpty) {
      return AppStrings.current().errNoActiveTripComplete;
    }

    _isCompletingTrip = true;
    notifyListeners();
    try {
      final offer = _acceptedRideOffer!;
      final actualFare = offer.hasRiderStopRequest && offer.requestedFare != null
          ? offer.requestedFare!
          : offer.estimatedFare;

      final response = await AuthService.completeRide(
        rideId: rideId,
        actualFare: actualFare,
      );

      if (response['success'] != true) {
        return AuthService.extractErrorMessage(
          response,
          fallback: AppStrings.current().errCompleteTrip,
        );
      }

      _lastCompletedRideDetails = AuthService.extractCompleteRideDetails(
        response,
        distanceKm: offer.distanceKm,
        durationMinutes: offer.durationMinutes,
        riderRating: offer.riderRating,
      );

      _hasActiveTrip = false;
      _lastCompletedRideId = rideId;
      _acceptedRideOffer = null;
      _persistedRideOffer = null;
      _persistAcceptedRide(null);
      _clearRideRoute();
      stopRideStatusPolling();
      if (_isOnline) {
        startNearbyRidesPolling();
      }
      unawaited(loadTodayStats());
      if (_hasLoadedEarnings) {
        unawaited(loadSignupPerformanceBonus());
      }
      unawaited(_recenterMapOnDriverAfterLayout(resetBearing: true));
      return null;
    } finally {
      _isCompletingTrip = false;
      notifyListeners();
    }
  }

  void dismissRideCompleted() {
    _lastCompletedRideId = null;
    _lastCompletedRideDetails = null;
    _clearRideRoute();
    notifyListeners();
    unawaited(_recenterMapOnDriverAfterLayout(resetBearing: true));
  }

  void attachMapController(GoogleMapController controller) {
    _mapController = controller;
    _mapSurfaceReady = false;
    unawaited(
      _onHomeMapCreated().whenComplete(() {
        _mapSurfaceReady = true;
        notifyListeners();
      }),
    );
  }

  void detachMapController() {
    if (_mapController == null) return;
    _mapController = null;
    _mapSurfaceReady = false;
    _mapSessionId++;
  }

  Future<void> _onHomeMapCreated() async {
    if (!_locationReady && !_isInitializingHomeMap) {
      _isInitializingHomeMap = true;
      try {
        await initializeLocation();
      } finally {
        _isInitializingHomeMap = false;
      }
    }

    if (_mapController == null) return;
    await _syncMapCamera(animated: false);
  }

  Future<void> _syncMapCamera({required bool animated}) async {
    final controller = _mapController;
    if (controller == null) return;

    final target = _pendingCameraTarget ?? _cameraTarget;
    _pendingCameraTarget = null;
    final position = CameraPosition(
      target: target,
      zoom: _pendingCameraZoom,
      bearing: _pendingNavigationCamera ? _pendingCameraBearing : 0,
    );
    _pendingNavigationCamera = false;

    final update = CameraUpdate.newCameraPosition(position);
    try {
      if (animated) {
        await controller.animateCamera(update);
      } else {
        await controller.moveCamera(update);
      }
    } on PlatformException {
      // Ignore transient camera failures during map init/resume.
    } catch (_) {}
  }

  Future<void> initializeLocation() async {
    if (_locationReady) {
      _hasDriverMarker = true;
      await _showDriverPointerAtCurrentLocation();
      if (_isOnline || _isEnRouteForLocation) {
        startLocationUpdates();
      }
      return;
    }

    final result = await centerOnUser(forceRefresh: false);
    if (!result.isOk) return;
  }

  Future<LocationAccessResult> centerOnUser({bool forceRefresh = true}) async {
    if (!forceRefresh && _locationReady) {
      _hasDriverMarker = true;
      await _showDriverPointerAtCurrentLocation();
      return const LocationAccessResult.ok();
    }

    final result = await LocationTrackerService.getCurrentLocation(
      allowStaleLastKnown: !forceRefresh,
    );
    if (!result.isOk) {
      if (forceRefresh) {
        _locationDenied = true;
        notifyListeners();
      }
      return result;
    }

    _setDriverPosition(
      LatLng(result.location!.latitude, result.location!.longitude),
    );
    _locationReady = true;
    _locationDenied = false;

    _hasDriverMarker = true;
    await _showDriverPointerAtCurrentLocation();
    await _animateTo(_driverPosition);
    if (_isOnline) {
      _applyOnlineSideEffects(true);
    }
    return const LocationAccessResult.ok();
  }

  Future<void> _showDriverPointerAtCurrentLocation() async {
    if (_driverCarIcon != null) return;
    _driverCarIcon = await MapMarkerIcons.driverCarMarker();
    notifyListeners();
  }

  Future<void> _refreshDriverPosition() async {
    final result = await LocationTrackerService.getCurrentLocation(
      requestPermissionIfNeeded: false,
    );
    if (!result.isSuccess) return;

    _setDriverPosition(
      LatLng(result.location!.latitude, result.location!.longitude),
    );
    _locationReady = true;
    _locationDenied = false;
  }

  Future<void> _recenterMapOnDriver({bool resetBearing = false}) async {
    await _refreshDriverPosition();
    if (_hasActiveTrip && !resetBearing) {
      _navigationCameraBearing = _driverHeading;
      _maybeFollowNavigationCamera(force: true);
    } else {
      await _animateTo(_driverPosition, bearing: 0);
    }
    notifyListeners();
  }

  Future<void> _recenterMapOnDriverAfterLayout({bool resetBearing = false}) async {
    await _recenterMapOnDriver(resetBearing: resetBearing);

    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _recenterMapOnDriver(resetBearing: resetBearing).whenComplete(completer.complete),
      );
    });
    await completer.future;
  }

  Future<void> _prepareRideMap() async {
    await _ensureRideMapIcons();
    _rideMapIconsReady = true;
    notifyListeners();
    await _updateRideMapCamera(animated: true);
  }

  Future<void> _ensureRideMapIcons() async {
    final needsNotify =
        _driverCarIcon == null || _pickupPinIcon == null;
    _driverCarIcon ??= await MapMarkerIcons.driverCarMarker();
    _pickupPinIcon ??= await MapMarkerIcons.pickupPin();
    if (needsNotify) {
      notifyListeners();
    }
  }

  Future<void> _updateRideMapCamera({bool animated = false}) async {
    if (_hasActiveTrip) {
      _navigationCameraBearing = _driverHeading;
      _maybeFollowNavigationCamera(force: animated);
      return;
    }
    await _fitRouteCamera();
  }

  Future<void> _followDriverNavigationCamera({
    bool animated = false,
    required double bearing,
  }) async {
    if (!_hasActiveTrip) return;

    final normalizedBearing = (bearing % 360 + 360) % 360;
    final position = CameraPosition(
      target: _driverPosition,
      zoom: _navigationFollowZoom,
      bearing: normalizedBearing,
    );
    _cameraTarget = _driverPosition;

    final controller = _mapController;
    if (controller == null) {
      _pendingCameraTarget = _driverPosition;
      _pendingCameraZoom = _navigationFollowZoom;
      _pendingCameraBearing = normalizedBearing;
      _pendingNavigationCamera = true;
      return;
    }

    final update = CameraUpdate.newCameraPosition(position);
    try {
      if (animated) {
        await controller.animateCamera(update);
      } else {
        await controller.moveCamera(update);
      }
    } on PlatformException {
      // Keep the active trip map alive; camera updates can fail transiently.
    } catch (_) {}
  }

  void _maybeFollowNavigationCamera({bool force = false}) {
    if (!_hasActiveTrip) return;

    final now = DateTime.now();
    if (!force &&
        _lastNavigationCameraUpdate != null &&
        now.difference(_lastNavigationCameraUpdate!) <
            _navigationCameraMinInterval) {
      return;
    }

    var movedEnough = _lastCameraFollowPosition == null;
    if (_lastCameraFollowPosition != null) {
      movedEnough = Geolocator.distanceBetween(
            _lastCameraFollowPosition!.latitude,
            _lastCameraFollowPosition!.longitude,
            _driverPosition.latitude,
            _driverPosition.longitude,
          ) >=
          _cameraMinMoveMeters;
    }

    final bearingDelta = _angleDelta(_navigationCameraBearing, _driverHeading);
    final turningEnough = _lastGpsSpeedMps >= _cameraMinSpeedMps &&
        bearingDelta.abs() >= _cameraMinBearingDelta;
    final shouldUpdateBearing = force || turningEnough;

    if (!force && !movedEnough && !shouldUpdateBearing) {
      return;
    }

    if (shouldUpdateBearing) {
      _navigationCameraBearing = _lerpAngle(
        _navigationCameraBearing,
        _driverHeading,
        force ? 1 : 0.35,
      );
    }

    _lastNavigationCameraUpdate = now;
    _lastCameraFollowPosition = _driverPosition;
    unawaited(
      _followDriverNavigationCamera(
        animated: force,
        bearing: _navigationCameraBearing,
      ),
    );
  }

  void _ensureNavigationSmoothingActive() {
    if (_navigationSmoothingTimer != null) return;
    _navigationSmoothingTimer = Timer.periodic(
      _navigationSmoothInterval,
      (_) => _tickNavigationSmoothing(),
    );
  }

  void _stopNavigationSmoothing() {
    _navigationSmoothingTimer?.cancel();
    _navigationSmoothingTimer = null;
  }

  void _tickNavigationSmoothing() {
    if (!_shouldSnapToRoute) {
      _stopNavigationSmoothing();
      return;
    }

    final route = _activeRoutePoints;
    if (route.length < 2) return;

    final distDelta = _targetRouteDistance - _routeDistanceTraveled;

    // Hard-freeze the car when stopped or crawling — GPS jitter causes shake.
    if (_lastGpsSpeedMps < _routeFreezeSpeedMps &&
        distDelta.abs() < _routeFreezeDistanceMeters) {
      return;
    }

    final headingDelta = _angleDelta(_driverHeading, _targetHeading).abs();
    if (distDelta.abs() < 0.15 && headingDelta < 3) {
      return;
    }

    if (distDelta.abs() > 0.15) {
      final factor = _lastGpsSpeedMps >= 4
          ? _routeDistanceSmoothFactor
          : _routeDistanceSmoothFactorSlow;
      final maxStep = (_lastGpsSpeedMps * 0.055).clamp(0.15, 2.5);
      final step = (distDelta * factor).clamp(-maxStep, maxStep);
      _routeDistanceTraveled += step;
    }

    if (headingDelta >= 3 && _lastGpsSpeedMps >= _routeFreezeSpeedMps) {
      _driverHeading = _lerpAngle(
        _driverHeading,
        _targetHeading,
        _headingSmoothFactor,
      );
    }

    final onRoute =
        RideRouteProgress.positionAtDistance(route, _routeDistanceTraveled);
    _applyDriverPosition(
      onRoute.point,
      notify: true,
      skipHeadingUpdate: true,
    );
  }

  void _advanceRouteTargetFromGps(double alongRoute, List<LatLng> route) {
    final delta = alongRoute - _targetRouteDistance;

    if (_lastGpsSpeedMps < _routeFreezeSpeedMps) {
      if (delta.abs() < 6) return;
    } else if (delta < -_routeTargetMaxBackwardMeters) {
      _targetRouteDistance = alongRoute;
    } else if (delta > _routeTargetMinAdvanceMeters) {
      _targetRouteDistance = alongRoute;
    } else {
      return;
    }

    final onRoute =
        RideRouteProgress.positionAtDistance(route, _targetRouteDistance);
    _updateTargetHeading(onRoute.bearing);
  }

  bool _coordinatesNear(LatLng a, LatLng b, {double thresholdMeters = 120}) {
    return Geolocator.distanceBetween(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        ) <=
        thresholdMeters;
  }

  void _cacheDestinationRoute(List<LatLng> points, LatLng destination) {
    if (points.length < 2) return;
    _cachedDestinationRoute = points;
    _cachedDestinationLatLng = destination;
  }

  void _showDestinationRouteNow() {
    _resolveDestinationForOffer(_acceptedRideOffer);

    if (_fullRoutePoints.length >= 2) {
      _syncCarToActiveRoute(notify: true);
      return;
    }

    if (_cachedDestinationRoute.length >= 2 &&
        _cachedDestinationLatLng != null &&
        _coordinatesNear(_cachedDestinationLatLng!, _destinationLocation)) {
      _fullRoutePoints = _cachedDestinationRoute;
      _syncCarToActiveRoute(notify: true);
    }
  }

  Future<void> _refreshTripRouteIfNeeded() async {
    if (!_hasActiveTrip) return;

    final endpoints = _resolveRouteEndpoints();
    if (_fullRoutePoints.length >= 2 &&
        _cachedDestinationLatLng != null &&
        _coordinatesNear(_cachedDestinationLatLng!, endpoints.end)) {
      final distFromRouteStart = Geolocator.distanceBetween(
        endpoints.start.latitude,
        endpoints.start.longitude,
        _fullRoutePoints.first.latitude,
        _fullRoutePoints.first.longitude,
      );
      if (distFromRouteStart < 200) {
        return;
      }
    }

    await _fetchAndApplyRoute(
      origin: endpoints.start,
      destination: endpoints.end,
      generation: ++_routeFetchGeneration,
      showOverviewImmediately: true,
    );
  }

  void _syncCarToActiveRoute({required bool notify}) {
    if (_fullRoutePoints.length < 2) return;

    final snapFrom = _locationReady ? _gpsPosition : _driverPosition;
    final minDist =
        (_targetRouteDistance - 30).clamp(0.0, double.infinity);
    final snapped = RideRouteProgress.snapToRouteAhead(
      _fullRoutePoints,
      snapFrom,
      minDistanceAlongRoute: minDist,
    );
    final alongRoute = snapped.distanceAlongRoute;
    final onRoute = RideRouteProgress.positionAtDistance(
      _fullRoutePoints,
      alongRoute,
    );

    _targetRouteDistance = alongRoute;
    _routeDistanceTraveled = alongRoute;
    _targetHeading = onRoute.bearing;

    final jumpMeters = Geolocator.distanceBetween(
      _driverPosition.latitude,
      _driverPosition.longitude,
      onRoute.point.latitude,
      onRoute.point.longitude,
    );
    if (jumpMeters > 1.5 || !_hasDriverMarker) {
      _driverPosition = onRoute.point;
      _driverHeading = onRoute.bearing;
    }

    _ensureNavigationSmoothingActive();
    if (notify) {
      notifyListeners();
    }
  }

  static double _lerpAngle(double from, double to, double t) {
    final delta = _angleDelta(from, to);
    return (from + delta * t) % 360;
  }

  static double _angleDelta(double from, double to) {
    return ((to - from + 540) % 360) - 180;
  }

  Future<void> _prefetchDestinationRoute(NearbyRideOffer offer) async {
    _resolveDestinationForOffer(offer);
    final origin = _locationReady ? _gpsPosition : _driverPosition;
    final destination = _destinationLocation;
    await _fetchAndApplyRoute(
      origin: origin,
      destination: destination,
      generation: ++_routeFetchGeneration,
      showOverviewImmediately: true,
    );
  }

  void _resolveDestinationForOffer(NearbyRideOffer? offer) {
    final origin = _hasDriverMarker ? _driverPosition : defaultPosition;
    _pickupLocation = offer?.pickupLatLng ??
        LatLng(
          origin.latitude + 0.012,
          origin.longitude + 0.008,
        );
    _destinationLocation = offer?.dropoffLatLng ??
        LatLng(
          origin.latitude - 0.018,
          origin.longitude + 0.022,
        );
    if (offer?.hasRiderStopRequest == true &&
        offer?.requestedDropoffLatLng != null) {
      _destinationLocation = offer!.requestedDropoffLatLng!;
    }
  }

  ({LatLng start, LatLng end}) _resolveRouteEndpoints() {
    final origin = _hasDriverMarker ? _driverPosition : defaultPosition;
    final offer = _acceptedRideOffer ?? _currentRideOffer;
    _resolveDestinationForOffer(offer);

    if (_hasActivePickup) {
      _pickupLegStartPosition = origin;
      return (
        start: _locationReady ? _gpsPosition : origin,
        end: _pickupLocation,
      );
    }

    if (_hasActiveTrip) {
      return (
        start: _locationReady ? _gpsPosition : _driverPosition,
        end: _destinationLocation,
      );
    }

    if (_hasActiveRide) {
      return (
        start: _pickupLocation,
        end: _destinationLocation,
      );
    }

    return (start: origin, end: _pickupLocation);
  }

  Future<void> _setupRideRoute() async {
    final endpoints = _resolveRouteEndpoints();
    await _fetchAndApplyRoute(
      origin: endpoints.start,
      destination: endpoints.end,
      generation: ++_routeFetchGeneration,
      showOverviewImmediately: true,
    );
  }

  Future<void> _fetchAndApplyRoute({
    required LatLng origin,
    required LatLng destination,
    required int generation,
    required bool showOverviewImmediately,
  }) async {
    final points = await DirectionsService.fetchDrivingRoute(
      origin: origin,
      destination: destination,
      onOverviewReady: showOverviewImmediately
          ? (overview) {
              if (generation != _routeFetchGeneration) return;
              _applyFetchedRoute(
                overview,
                snapFrom: _locationReady ? _gpsPosition : origin,
                destination: destination,
              );
            }
          : null,
    );

    if (generation != _routeFetchGeneration) return;
    if (points.length >= 2) {
      _applyFetchedRoute(
        points,
        snapFrom: _locationReady ? _gpsPosition : origin,
        destination: destination,
      );
    } else if (_fullRoutePoints.length < 2) {
      _fullRoutePoints = [];
      notifyListeners();
    }
  }

  void _applyFetchedRoute(
    List<LatLng> points, {
    required LatLng snapFrom,
    LatLng? destination,
  }) {
    _fullRoutePoints = points;
    if (destination != null &&
        _coordinatesNear(destination, _destinationLocation, thresholdMeters: 80)) {
      _cacheDestinationRoute(points, _destinationLocation);
    }

    _syncCarToActiveRoute(notify: true);
  }

  Future<void> _maybeRefreshPickupRoute() async {
    if (!_hasActivePickup || !hasAcceptedRide) return;

    final now = DateTime.now();
    if (_lastPickupRouteRefreshAt != null &&
        now.difference(_lastPickupRouteRefreshAt!) <
            const Duration(seconds: 20)) {
      return;
    }

    final origin = _locationReady ? _gpsPosition : _driverPosition;
    final lastOrigin = _lastPickupRouteOrigin;
    if (lastOrigin != null) {
      final moved = Geolocator.distanceBetween(
        lastOrigin.latitude,
        lastOrigin.longitude,
        origin.latitude,
        origin.longitude,
      );
      if (moved < 80) return;
    }

    _lastPickupRouteRefreshAt = now;
    _lastPickupRouteOrigin = origin;

    final points = await DirectionsService.fetchDrivingRoute(
      origin: origin,
      destination: _pickupLocation,
    );
    if (points.length < 2 || !_hasActivePickup) return;

    _fullRoutePoints = points;
    final snapped = RideRouteProgress.snapToRouteAhead(
      points,
      _gpsPosition,
      minDistanceAlongRoute: _targetRouteDistance,
    );
    final alongRoute = snapped.distanceAlongRoute;
    final onRoute = RideRouteProgress.positionAtDistance(points, alongRoute);
    _targetRouteDistance = alongRoute;
    _updateTargetHeading(onRoute.bearing);
    _ensureNavigationSmoothingActive();
    notifyListeners();
  }

  void _clearRideRoute() {
    _fullRoutePoints = [];
    _cachedDestinationRoute = const [];
    _cachedDestinationLatLng = null;
    _routeDistanceTraveled = 0;
    _targetRouteDistance = 0;
    _targetHeading = 0;
    _navigationCameraBearing = 0;
    _lastCameraFollowPosition = null;
    _rideMapIconsReady = false;
    _lastPickupRouteRefreshAt = null;
    _lastPickupRouteOrigin = null;
    _stopNavigationSmoothing();
  }

  bool get _shouldSnapToRoute =>
      hasAcceptedRide && _activeRoutePoints.length >= 2;

  void _updateNavigationHeading() {
    final target = _hasActiveTrip
        ? _destinationLocation
        : _hasActiveRide
            ? _destinationLocation
            : _pickupLocation;

    _driverHeading = Geolocator.bearingBetween(
      _driverPosition.latitude,
      _driverPosition.longitude,
      target.latitude,
      target.longitude,
    );
  }

  void _updateDriverHeadingFromMovement(LatLng previous, LatLng next) {
    if (_lastGpsSpeedMps < _headingMinSpeedMps) return;

    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      next.latitude,
      next.longitude,
    );
    if (distance < 4) return;

    final bearing = Geolocator.bearingBetween(
      previous.latitude,
      previous.longitude,
      next.latitude,
      next.longitude,
    );
    final delta = _angleDelta(_driverHeading, bearing).abs();
    if (delta < _headingMinDeltaDegrees) return;

    _driverHeading = _lerpAngle(_driverHeading, bearing, 0.4);
  }

  void _updateTargetHeading(double bearing) {
    final delta = _angleDelta(_targetHeading, bearing).abs();
    if (_lastGpsSpeedMps < _headingMinSpeedMps && delta < 25) {
      return;
    }
    if (delta < 4) return;
    _targetHeading = bearing;
  }

  Future<void> _fitRouteCamera() async {
    final controller = _mapController;
    if (controller == null || _activeRoutePoints.isEmpty) return;

    final bounds = _boundsFromPoints(_activeRoutePoints);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 72),
    );
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _setDriverPosition(LatLng position, {bool notify = false}) {
    _gpsPosition = position;

    if (!_shouldSnapToRoute) {
      _applyDriverPosition(position, notify: notify);
      return;
    }

    final route = _activeRoutePoints;
    if (route.length < 2) {
      _applyDriverPosition(position, notify: notify);
      return;
    }

    final snapped = RideRouteProgress.snapToRouteAhead(
      route,
      position,
      minDistanceAlongRoute: _targetRouteDistance,
    );
    _advanceRouteTargetFromGps(snapped.distanceAlongRoute, route);
    _ensureNavigationSmoothingActive();
  }

  void _applyDriverPosition(
    LatLng position, {
    required bool notify,
    bool skipHeadingUpdate = false,
  }) {
    final previous = _driverPosition;
    final movedMeters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );
    final changed = movedMeters > 0.000001;
    _cameraTarget = position;
    if (changed && _hasDriverMarker && !skipHeadingUpdate) {
      _updateDriverHeadingFromMovement(previous, position);
    }
    _driverPosition = position;
    _hasDriverMarker = true;
    if (_hasActivePickup) {
      _maybeNotifyPickupEtaChanged();
    }
    if (!notify) return;

    // Earnings screens cover the map — avoid rebuilding the native surface on GPS ticks.
    if (_selectedTab == DashboardTab.earnings && !hasAcceptedRide) {
      return;
    }

    if (_hasActiveTrip || _shouldSnapToRoute) {
      if (movedMeters >= _markerNotifyMinMoveMeters) {
        notifyListeners();
      }
      return;
    }

    if (changed || hasAcceptedRide) {
      notifyListeners();
    }
  }

  Future<void> _animateTo(
    LatLng target, {
    double zoom = 16,
    double bearing = 0,
  }) async {
    _cameraTarget = target;
    final mapController = _mapController;
    if (mapController == null) {
      _pendingCameraTarget = target;
      _pendingCameraZoom = zoom;
      _pendingCameraBearing = bearing;
      _pendingNavigationCamera = false;
      notifyListeners();
      return;
    }

    await mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom, bearing: bearing),
      ),
    );
  }

  @override
  void dispose() {
    stopLocationUpdates();
    _stopNavigationSmoothing();
    stopNearbyRidesPolling();
    stopRideStatusPolling();
    _stopPickupEtaTracking();
    detachMapController();
    super.dispose();
  }
}
