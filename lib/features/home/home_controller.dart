import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/api_config.dart';
import '../../config/app_strings.dart';
import '../../services/active_ride_storage.dart';
import '../../services/added_stop_arrival_sound_service.dart';
import '../../services/auth_service.dart';
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

  var _isOnline = false;
  var _isUpdatingOnlineStatus = false;
  var _hasSyncedOnlineFromStats = false;
  var _isLoadingTodayStats = true;
  var _isRefreshingDashboard = false;
  var _hasLoadedDashboardStats = false;
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
  DateTime? _lastNavigationCameraUpdate;
  var _cameraTarget = defaultPosition;
  var _driverPosition = defaultPosition;
  var _hasDriverMarker = false;
  var _locationReady = false;
  var _locationDenied = false;
  var _hasRideRequest = false;
  var _hasActivePickup = false;
  var _hasActiveRide = false;
  var _hasActiveTrip = false;
  var _showsRideCompleted = false;
  String? _lastCompletedRideId;
  DriverRideDetails? _lastCompletedRideDetails;
  var _showsTopUp = false;
  var _showsWithdrawal = false;
  static const _locationUpdateIntervalIdle = Duration(seconds: 8);
  static const _locationUpdateIntervalEnRoute = Duration(seconds: 2);
  static const _navigationFollowZoom = 18.0;
  static const _navigationCameraMinInterval = Duration(milliseconds: 250);

  Timer? _nearbyRidesPollingTimer;
  Timer? _rideStatusPollingTimer;
  Timer? _pickupEtaTickTimer;
  Timer? _locationUpdateTimer;
  Timer? _driverAnimationTimer;
  StreamSubscription<Position>? _positionStreamSubscription;
  final _rideRealtimeService = RideRealtimeService();
  var _isLocationUpdateInFlight = false;
  var _positionStreamEnRoute = false;
  DateTime? _lastBackendLocationPost;
  DateTime _lastAnimationNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
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
  NearbyRideOffer? _currentRideOffer;
  NearbyRideOffer? _acceptedRideOffer;
  NearbyRideOffer? _persistedRideOffer;

  BitmapDescriptor? _driverCarIcon;
  BitmapDescriptor? _pickupPinIcon;
  var _rideMapIconsReady = false;
  var _driverHeading = 0.0;
  var _pickupLocation = defaultPosition;
  var _destinationLocation = defaultPosition;
  var _pickupLegStartPosition = defaultPosition;
  var _fullRoutePoints = <LatLng>[];
  var _routeDistanceTraveled = 0.0;
  final _acknowledgedStopKeys = <String>{};
  final _arrivedAtStopKeys = <String>{};
  RiderStopNotification? _pendingRiderStopNotification;
  AddedStopArrivalNotification? _pendingAddedStopArrival;

  bool get isOnline => _isOnline;
  bool get isUpdatingOnlineStatus => _isUpdatingOnlineStatus;
  bool get isLoadingTodayStats => _isLoadingTodayStats;
  bool get isLoadingSignupBonus => _isLoadingSignupBonus;
  SignupPerformanceBonus? get signupPerformanceBonus => _signupPerformanceBonus;
  bool get isLoadingReferDriver => !_referralStateLoaded;
  bool get canShowReferDriver => AuthService.canShowReferDriver;
  String? get referralCode => AuthService.referralCode;
  bool get isLoadingWalletBalance => _isLoadingWalletBalance;
  bool get isProcessingTopUp => _isProcessingTopUp;
  bool get isProcessingWithdrawal => _isProcessingWithdrawal;
  DriverWalletBalance? get walletBalance => _walletBalance;
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
  RiderStopNotification? get pendingRiderStopNotification =>
      _pendingRiderStopNotification;
  AddedStopArrivalNotification? get pendingAddedStopArrival =>
      _pendingAddedStopArrival;
  bool get showsRideCompleted => _showsRideCompleted;
  String? get lastCompletedRideId => _lastCompletedRideId;
  DriverRideDetails? get lastCompletedRideDetails => _lastCompletedRideDetails;
  bool get showsTopUp => _showsTopUp;
  bool get showsWithdrawal => _showsWithdrawal;
  bool get showsEarningsFlow => _showsTopUp || _showsWithdrawal;
  bool get showsBottomModal =>
      hasRideRequest || _hasActivePickup || _showsRideCompleted;
  bool get showsRidePanel => _hasActiveRide || _hasActiveTrip;
  bool get hasAcceptedRide =>
      _hasActivePickup || _hasActiveRide || _hasActiveTrip;
  DashboardTab get selectedTab => _selectedTab;
  LatLng get cameraTarget => _cameraTarget;
  bool get locationReady => _locationReady;
  bool get locationDenied => _locationDenied;
  bool get showsDriverPointer =>
      _hasDriverMarker && _activeDriverIcon != null;
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

  BitmapDescriptor? get _activeDriverIcon => _driverCarIcon;

  Set<Marker> get markers {
    final markers = <Marker>{};

    if (hasAcceptedRide && _rideMapIconsReady && _pickupPinIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation,
          icon: _pickupPinIcon!,
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }

    final driverIcon = _activeDriverIcon;
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

    return markers;
  }

  Set<Polyline> get polylines {
    if (!hasAcceptedRide || _fullRoutePoints.length < 2) {
      return {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('ride_route'),
        points: _activeRoutePoints,
        color: _routeColor,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  List<LatLng> get _activeRoutePoints {
    if (_fullRoutePoints.length < 3) return _fullRoutePoints;
    if (_hasActivePickup) {
      return _fullRoutePoints.sublist(0, 3);
    }
    if (_hasActiveRide) {
      return _fullRoutePoints.sublist(0, 3);
    }
    return _fullRoutePoints;
  }

  Future<String?> toggleOnlineStatus() async {
    if (_isUpdatingOnlineStatus) return null;

    final targetStatus = !_isOnline;
    final previousStatus = _isOnline;

    _isUpdatingOnlineStatus = true;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);

    double? latitude;
    double? longitude;

    try {
      if (targetStatus) {
        final locationResult = await LocationTrackerService.getCurrentLocation();
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
      return;
    }

    stopLocationUpdates();
    stopNearbyRidesPolling();
    stopRideStatusPolling();
    dismissRideRequest();
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
    _restartPositionStream(enRoute: enRoute);

    final interval = _resolveLocationUpdateInterval();
    _locationUpdateTimer?.cancel();
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
    _stopPositionStream();
    _driverAnimationTimer?.cancel();
    _driverAnimationTimer = null;
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
    _applyDeviceHeading(position);
    _setDriverPosition(target, notify: true, animate: true);
    _maybeSyncLocationToBackend();
  }

  void _applyDeviceHeading(Position position) {
    final heading = position.heading;
    if (position.speed >= 1 &&
        heading >= 0 &&
        heading <= 360 &&
        !heading.isNaN) {
      _driverHeading = heading;
    }
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
        latitude: _driverPosition.latitude,
        longitude: _driverPosition.longitude,
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
    _isLoadingTodayStats = true;
    notifyListeners();

    try {
      final response = await AuthService.getDriverTodayStats();
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
            }
          }
        }
      }
    } finally {
      _isLoadingTodayStats = false;
      if (_isOnline && !_isUpdatingOnlineStatus) {
        _applyOnlineSideEffects(true);
      }
      notifyListeners();
    }
  }

  /// Refreshes driver tab data after the app returns from a long idle period.
  Future<void> refreshDashboardOnResume() async {
    if (_isRefreshingDashboard) return;

    _isRefreshingDashboard = true;
    try {
      await AuthService.maintainSession();
      await Future.wait([
        loadTodayStats(),
        loadDriverProfile(),
        loadReferDriver(),
      ]);
      if (hasAcceptedRide || _isPendingRideAcceptance) {
        await _fetchRideStatus(allowWhenOffline: true);
      }
    } finally {
      _isRefreshingDashboard = false;
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

  Future<void> loadWalletBalance() async {
    _isLoadingWalletBalance = true;
    notifyListeners();

    final response = await AuthService.getWalletBalance();
    final wallet = AuthService.extractWalletBalance(response);

    if (wallet != null) {
      _walletBalance = wallet;
      final today = wallet.today;
      if (today != null) {
        _todayEarningsAmount = today.totalEarnings;
        _todayRidesDisplay = today.ridesCompleted.toString();
      }
    }

    _isLoadingWalletBalance = false;
    notifyListeners();
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

    if (_hasLoadedEarnings) return;

    if (_isLoadingWalletBalance || _isLoadingCompletedTrips) {
      return;
    }

    _isLoadingWalletBalance = true;
    _isLoadingCompletedTrips = true;
    notifyListeners();

    await Future.wait([
      loadWalletBalance(),
      loadCompletedTrips(offset: 0),
    ]);
    _hasLoadedEarnings = true;
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
    _showsWithdrawal = true;
    unawaited(ensureEarningsLoaded());
    notifyListeners();
  }

  void closeWithdrawal() {
    _showsWithdrawal = false;
    unawaited(loadWalletBalance());
    notifyListeners();
  }

  void closeEarningsFlow() {
    _showsTopUp = false;
    _showsWithdrawal = false;
    unawaited(refreshEarnings());
    notifyListeners();
  }

  void startNearbyRidesPolling() {
    if (!_isOnline || hasAcceptedRide) {
      return;
    }

    _nearbyRidesPollingTimer?.cancel();
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
    _pickupEtaTickTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!_hasActivePickup || _acceptedRideOffer == null) return;
        notifyListeners();
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
    unawaited(_rideRealtimeService.unsubscribe());
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
        !hasAcceptedRide) {
      return;
    }

    _rideStatusPollingTimer?.cancel();
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
    return null;
  }

  Future<void> _fetchRideStatus({bool allowWhenOffline = false}) async {
    if (_isFetchingRideStatus) return;
    if (!allowWhenOffline &&
        !_isOnline &&
        !_isPendingRideAcceptance &&
        !hasAcceptedRide) {
      return;
    }

    _isFetchingRideStatus = true;
    try {
      final response = await AuthService.getDriverRideStatus(
        rideId: _rideStatusPollRideId,
      );
      final ride = AuthService.extractDriverRideStatus(response);

      if (ride == null) {
        if (_isPendingRideAcceptance) return;
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
      stopNearbyRidesPolling();
      if (enteringPickup) {
        _setupRideRoute();
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

    if (status == 'cancelled' ||
        status == 'canceled' ||
        status == 'declined' ||
        status == 'completed') {
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
    _setupRideRoute();
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
    _setupRideRoute();
    if (_shouldFollowRoute) {
      final snapped =
          RideRouteProgress.snapToRoute(_activeRoutePoints, _pickupLocation);
      _routeDistanceTraveled = snapped.distanceAlongRoute;
      _driverPosition = snapped.point;
    } else {
      _driverPosition = _pickupLocation;
    }
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

  Future<void> _fetchNearbyRides() async {
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
        if (_hasRideRequest) {
          dismissRideRequest();
        }
        return;
      }

      final offer = NearbyRideOffer.fromMap(rides.first);
      if (offer == null || !offer.isPending) {
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

      if (shouldNotify) {
        unawaited(RideRequestSoundService.play(offer.id));
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

  void _showRideRequest(NearbyRideOffer offer) {
    if (hasAcceptedRide || _isAcceptingRide || _isPendingRideAcceptance) {
      return;
    }

    _currentRideOffer = offer;
    _hasRideRequest = true;
  }

  void dismissRideRequest() {
    if (_isAcceptingRide) return;

    unawaited(RideRequestSoundService.stop());
    _hasRideRequest = false;
    _currentRideOffer = null;
    notifyListeners();
  }

  Future<void> declineRideRequest() async {
    if (_isAcceptingRide || _isDecliningRide) return;

    final rideId = _currentRideOffer?.id ?? _pendingAcceptRideId;
    if (rideId == null || rideId.isEmpty) {
      _isPendingRideAcceptance = false;
      _pendingAcceptRideId = null;
      dismissRideRequest();
      return;
    }

    _isDecliningRide = true;
    notifyListeners();
    try {
      await AuthService.rideResponse(rideId: rideId, action: 'decline');
      _isPendingRideAcceptance = false;
      _pendingAcceptRideId = null;
      dismissRideRequest();
    } finally {
      _isDecliningRide = false;
      notifyListeners();
    }
  }

  Future<String?> acceptRideRequest() async {
    final offer = _currentRideOffer;
    if (offer == null || _isAcceptingRide || _isDecliningRide) {
      return AppStrings.current().errNoRideToAccept;
    }

    _isAcceptingRide = true;
    stopNearbyRidesPolling();
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
        if (_isOnline) {
          startNearbyRidesPolling();
        }
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

      final stopNotification = _buildStopNotificationForOffer(acceptedOffer);
      if (stopNotification != null) {
        _pendingRiderStopNotification = stopNotification;
      }
      unawaited(RideRequestSoundService.stop());
      _persistAcceptedRide(offer);
      _startPickupEtaTracking(offer.id);
      startRideStatusPolling();
      startLocationUpdates();
      unawaited(_fetchRideStatus());
      return null;
    } finally {
      _isAcceptingRide = false;
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

      final offer = _acceptedRideOffer;
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
      _updateNavigationHeading();
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
      _showsRideCompleted = true;
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
    _showsRideCompleted = false;
    _lastCompletedRideId = null;
    _lastCompletedRideDetails = null;
    _clearRideRoute();
    notifyListeners();
    unawaited(_recenterMapOnDriverAfterLayout(resetBearing: true));
  }

  void attachMapController(GoogleMapController controller) {
    _mapController = controller;
    final pending = _pendingCameraTarget;
    if (pending == null) return;

    _pendingCameraTarget = null;
    final position = CameraPosition(
      target: pending,
      zoom: _pendingCameraZoom,
      bearing: _pendingNavigationCamera ? _pendingCameraBearing : 0,
    );
    _pendingNavigationCamera = false;
    unawaited(
      controller.animateCamera(CameraUpdate.newCameraPosition(position)),
    );
  }

  Future<void> initializeLocation() async {
    final result = await centerOnUser();
    if (!result.isOk) return;
  }

  Future<LocationAccessResult> centerOnUser() async {
    final result = await LocationTrackerService.getCurrentLocation();
    if (!result.isOk) {
      _locationDenied = true;
      notifyListeners();
      return result;
    }

    _setDriverPosition(
      LatLng(result.location!.latitude, result.location!.longitude),
    );
    _locationReady = true;
    _locationDenied = false;

    await _showDriverPointerAtCurrentLocation();
    await _animateTo(_driverPosition);
    if (_isOnline) {
      _applyOnlineSideEffects(true);
    }
    return const LocationAccessResult.ok();
  }

  Future<void> _showDriverPointerAtCurrentLocation() async {
    _driverCarIcon ??= await MapMarkerIcons.driverCarMarker();
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
      await _followDriverNavigationCamera(animated: true);
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
    _driverCarIcon ??= await MapMarkerIcons.driverCarMarker();
    _pickupPinIcon ??= await MapMarkerIcons.pickupPin();
    _rideMapIconsReady = true;
    notifyListeners();
    await _updateRideMapCamera(animated: true);
  }

  Future<void> _updateRideMapCamera({bool animated = false}) async {
    if (_hasActiveTrip) {
      await _followDriverNavigationCamera(animated: animated);
      return;
    }
    await _fitRouteCamera();
  }

  Future<void> _followDriverNavigationCamera({bool animated = false}) async {
    if (!_hasActiveTrip) return;

    final now = DateTime.now();
    if (!animated &&
        _lastNavigationCameraUpdate != null &&
        now.difference(_lastNavigationCameraUpdate!) <
            _navigationCameraMinInterval) {
      return;
    }
    _lastNavigationCameraUpdate = now;

    final bearing = (_driverHeading % 360 + 360) % 360;
    final position = CameraPosition(
      target: _driverPosition,
      zoom: _navigationFollowZoom,
      bearing: bearing,
    );
    _cameraTarget = _driverPosition;

    final controller = _mapController;
    if (controller == null) {
      _pendingCameraTarget = _driverPosition;
      _pendingCameraZoom = _navigationFollowZoom;
      _pendingCameraBearing = bearing;
      _pendingNavigationCamera = true;
      return;
    }

    final update = CameraUpdate.newCameraPosition(position);
    if (animated) {
      await controller.animateCamera(update);
    } else {
      await controller.moveCamera(update);
    }
  }

  void _setupRideRoute() {
    final origin = _hasDriverMarker ? _driverPosition : defaultPosition;
    final offer = _acceptedRideOffer ?? _currentRideOffer;
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
    if (_hasActivePickup) {
      _pickupLegStartPosition = origin;
    }
    _fullRoutePoints = _buildRoutePoints(
      origin,
      _pickupLocation,
      _destinationLocation,
    );
    final route = _activeRoutePoints;
    if (route.length >= 2) {
      final snapped = RideRouteProgress.snapToRoute(route, origin);
      _routeDistanceTraveled = snapped.distanceAlongRoute;
      _driverPosition = snapped.point;
    } else {
      _routeDistanceTraveled = 0;
      _driverPosition = origin;
    }
    _updateNavigationHeading();
  }

  void _clearRideRoute() {
    _fullRoutePoints = [];
    _routeDistanceTraveled = 0;
    _rideMapIconsReady = false;
  }

  bool get _shouldFollowRoute =>
      hasAcceptedRide && _activeRoutePoints.length >= 2;

  List<LatLng> _buildRoutePoints(
    LatLng start,
    LatLng pickup,
    LatLng destination,
  ) {
    final bendOne = LatLng(
      (start.latitude + pickup.latitude) / 2 + 0.003,
      (start.longitude + pickup.longitude) / 2 - 0.004,
    );
    final bendTwo = LatLng(
      (pickup.latitude + destination.latitude) / 2 - 0.002,
      (pickup.longitude + destination.longitude) / 2 + 0.005,
    );
    return [start, bendOne, pickup, bendTwo, destination];
  }

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
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      next.latitude,
      next.longitude,
    );
    if (distance < 2) {
      if (hasAcceptedRide) {
        _updateNavigationHeading();
      }
      return;
    }

    _driverHeading = Geolocator.bearingBetween(
      previous.latitude,
      previous.longitude,
      next.latitude,
      next.longitude,
    );
  }

  void _animateDriverMarkerTo(LatLng target, {bool notify = false}) {
    _driverAnimationTimer?.cancel();

    if (_shouldFollowRoute) {
      _animateDriverMarkerAlongRoute(target, notify: notify);
      return;
    }

    final from = _driverPosition;
    final distance = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      target.latitude,
      target.longitude,
    );

    if (distance < 2) {
      _applyDriverPosition(target, notify: notify);
      return;
    }

    final durationMs = (1000 + distance * 15).round().clamp(800, 3000);
    final startTime = DateTime.now();
    final fromLat = from.latitude;
    final fromLng = from.longitude;
    final latDiff = target.latitude - fromLat;
    final lngDiff = target.longitude - fromLng;

    _driverAnimationTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      final elapsed = DateTime.now().difference(startTime);
      final progress =
          (elapsed.inMilliseconds / durationMs).clamp(0.0, 1.0).toDouble();
      final eased = RideRouteProgress.easedProgress(progress);

      _applyDriverPosition(
        LatLng(fromLat + latDiff * eased, fromLng + lngDiff * eased),
        notify: false,
        checkArrival: false,
      );
      if (_hasActiveTrip) {
        unawaited(_followDriverNavigationCamera());
      }

      if (progress >= 1.0) {
        timer.cancel();
        _driverAnimationTimer = null;
        _applyDriverPosition(target, notify: notify);
        return;
      }

      if (!notify) return;

      final now = DateTime.now();
      if (now.difference(_lastAnimationNotifyAt) <
          const Duration(milliseconds: 50)) {
        return;
      }
      _lastAnimationNotifyAt = now;
      notifyListeners();
    });
  }

  void _animateDriverMarkerAlongRoute(LatLng rawTarget, {bool notify = false}) {
    final route = _activeRoutePoints;
    final snapped = RideRouteProgress.snapToRoute(route, rawTarget);
    final minDistance =
        (_routeDistanceTraveled - 15).clamp(0.0, double.infinity);
    final toDistance = snapped.distanceAlongRoute < minDistance
        ? minDistance
        : snapped.distanceAlongRoute;

    final fromDistance = _routeDistanceTraveled;
    final delta = toDistance - fromDistance;

    if (delta.abs() < 2) {
      final pos = RideRouteProgress.positionAtDistance(route, toDistance);
      _routeDistanceTraveled = toDistance;
      _applyDriverPosition(pos.point, notify: notify);
      return;
    }

    final durationMs = (1000 + delta.abs() * 15).round().clamp(800, 3000);
    final startTime = DateTime.now();

    _driverAnimationTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
      final elapsed = DateTime.now().difference(startTime);
      final progress =
          (elapsed.inMilliseconds / durationMs).clamp(0.0, 1.0).toDouble();
      final eased = RideRouteProgress.easedProgress(progress);
      final currentDistance = fromDistance + delta * eased;
      final pos = RideRouteProgress.positionAtDistance(route, currentDistance);

      _routeDistanceTraveled = currentDistance;
      _applyDriverPosition(pos.point, notify: false, checkArrival: false);
      if (_hasActiveTrip) {
        unawaited(_followDriverNavigationCamera());
      }

      if (progress >= 1.0) {
        timer.cancel();
        _driverAnimationTimer = null;
        _routeDistanceTraveled = toDistance;
        _applyDriverPosition(
          RideRouteProgress.positionAtDistance(route, toDistance).point,
          notify: notify,
        );
        return;
      }

      if (!notify) return;

      final now = DateTime.now();
      if (now.difference(_lastAnimationNotifyAt) <
          const Duration(milliseconds: 50)) {
        return;
      }
      _lastAnimationNotifyAt = now;
      notifyListeners();
    });
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

  void _setDriverPosition(
    LatLng position, {
    bool notify = false,
    bool animate = false,
  }) {
    if (animate && _hasDriverMarker) {
      _animateDriverMarkerTo(position, notify: notify);
      return;
    }
    if (_shouldFollowRoute) {
      final route = _activeRoutePoints;
      final snapped = RideRouteProgress.snapToRoute(route, position);
      final minDistance =
          (_routeDistanceTraveled - 15).clamp(0.0, double.infinity);
      _routeDistanceTraveled = snapped.distanceAlongRoute < minDistance
          ? minDistance
          : snapped.distanceAlongRoute;
      final snappedPosition = RideRouteProgress.positionAtDistance(
        route,
        _routeDistanceTraveled,
      ).point;
      _applyDriverPosition(snappedPosition, notify: notify);
      return;
    }
    _applyDriverPosition(position, notify: notify);
  }

  void _applyDriverPosition(
    LatLng position, {
    required bool notify,
    bool checkArrival = true,
  }) {
    final previous = _driverPosition;
    final changed = (previous.latitude - position.latitude).abs() > 0.000001 ||
        (previous.longitude - position.longitude).abs() > 0.000001;
    _cameraTarget = position;
    if (changed && _hasDriverMarker) {
      _updateDriverHeadingFromMovement(previous, position);
    }
    _driverPosition = position;
    _hasDriverMarker = true;
    final arrivalTriggered =
        checkArrival ? _checkAddedStopArrival(position) : false;
    if (_hasActiveTrip && changed) {
      unawaited(_followDriverNavigationCamera());
    }
    if (notify && (changed || hasAcceptedRide || arrivalTriggered)) {
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
    _driverAnimationTimer?.cancel();
    stopNearbyRidesPolling();
    stopRideStatusPolling();
    _stopPickupEtaTracking();
    _mapController?.dispose();
    super.dispose();
  }
}
