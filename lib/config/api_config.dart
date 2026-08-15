class ApiConfig {
  ApiConfig._();

  // Session persistence: in Supabase Dashboard → Authentication → Settings,
  // set a long refresh-token lifetime (e.g. 30+ days) and ensure driver-login /
  // OAuth responses return refresh_token + expires_in.
  static const supabaseUrl = 'https://bvazoowmmiymbbhxoggo.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2YXpvb3dtbWl5bWJiaHhvZ2dvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2OTQzMjQsImV4cCI6MjA3NTI3MDMyNH0.9vdJHTTnW38CctYwD9GZOvoX_SEu58FLu81mbjQFBdk';
  static const phoneVerificationConfirmUrl =
      '$supabaseUrl/functions/v1/phone-verification-confirm';
  static const driverLoginUrl = '$supabaseUrl/functions/v1/driver-login';
  static const driverOnboardingStatusUrl =
      '$supabaseUrl/functions/v1/driver-onboarding-status';
  static const driverSignupUrl = '$supabaseUrl/functions/v1/driver-signup';
  static const driverOAuthSignupUrl =
      '$supabaseUrl/functions/v1/driver-oauth-signup';
  static const uploadDocumentUrl = '$supabaseUrl/functions/v1/upload-document';
  static const deleteDocumentUrl = '$supabaseUrl/functions/v1/delete-document';
  static const forgotPasswordUrl = '$supabaseUrl/functions/v1/forgot-password';
  static const logoutUrl = '$supabaseUrl/functions/v1/logout';
  static const deleteAccountUrl = '$supabaseUrl/functions/v1/delete-account';
  static const driverSetStatusUrl = '$supabaseUrl/functions/v1/driver-set-status';
  static const updateDriverLocationUrl =
      '$supabaseUrl/functions/v1/update-driver-location';
  static const driverTodayStatsUrl = '$supabaseUrl/functions/v1/driver-today-stats';
  static const driverIncentiveProgressUrl =
      '$supabaseUrl/functions/v1/driver-incentive-progress';
  static const driverReferralGenerateUrl =
      '$supabaseUrl/functions/v1/driver-referral-generate';
  static const driverReferralProgressUrl =
      '$supabaseUrl/functions/v1/driver-referral-progress';
  static const getUserProfileUrl = '$supabaseUrl/functions/v1/get-user-profile';
  static const editProfileUrl = '$supabaseUrl/functions/v1/edit-profile';
  static const uploadAvatarUrl = '$supabaseUrl/functions/v1/upload-avatar';
  static const manageVehicleUrl = '$supabaseUrl/functions/v1/manage-vehicle';
  static const getNearbyRidesUrl = '$supabaseUrl/functions/v1/get-nearby-rides';
  static const rideResponseUrl = '$supabaseUrl/functions/v1/ride-response';
  static const driverRideStatusUrl = '$supabaseUrl/functions/v1/driver-ride-status';
  static const cancelRideUrl = '$supabaseUrl/functions/v1/cancel-ride';
  static const driverArrivedPickupUrl =
      '$supabaseUrl/functions/v1/driver-arrived-pickup';
  static const startRideUrl = '$supabaseUrl/functions/v1/start-ride';
  static const completeRideUrl = '$supabaseUrl/functions/v1/complete-ride';
  static const getChatHistoryUrl = '$supabaseUrl/functions/v1/get-chat-history';
  static const sendChatMessageUrl = '$supabaseUrl/functions/v1/send-chat-message';
  static const getWalletBalanceUrl = '$supabaseUrl/functions/v1/get-wallet-balance';
  static const driverCompletedTripsUrl =
      '$supabaseUrl/functions/v1/driver-completed-trips';
  static const driverCompletedTripDetailsUrl =
      '$supabaseUrl/functions/v1/driver-completed-trip-details';
  static const processDepositUrl = '$supabaseUrl/functions/v1/process-deposit';
  static const driverRequestPayoutUrl =
      '$supabaseUrl/functions/v1/driver-request-payout';
  static const driverTransferToCommissionUrl =
      '$supabaseUrl/functions/v1/driver-transfer-to-commission';
  static const callsStartUrl = '$supabaseUrl/functions/v1/calls-start';
  static const callsEndUrl = '$supabaseUrl/functions/v1/calls-end';
  static const rtcZegoTokenUrl = '$supabaseUrl/functions/v1/rtc-zego-token';
  static const rtcZegoRefreshUrl = '$supabaseUrl/functions/v1/rtc-zego-refresh';
  static const registerFcmTokenUrl = '$supabaseUrl/functions/v1/register-fcm-token';
  // Ride-request pushes must be data-only FCM (no notification/aps.alert block) with
  // type=new_ride_request, ride_id, pickup_address, dropoff_address, target_user_type=driver.
  // iOS fallback: aps.category = driver_ride_request_actions.
  static const adPlacementUrl = '$supabaseUrl/functions/v1/ad-placement';
  static const riderNotificationsUrl = '$supabaseUrl/functions/v1/rider-notifications';
  static const mySupportTicketsUrl =
      '$supabaseUrl/functions/v1/my-support-tickets';
  static const createSupportTicketUrl =
      '$supabaseUrl/functions/v1/create-support-ticket';
  static const supportTicketConversationUrl =
      '$supabaseUrl/functions/v1/support-ticket-conversation';
  static const tokenRefreshUrl = '$supabaseUrl/auth/v1/token?grant_type=refresh_token';
  static const passwordSignInUrl = '$supabaseUrl/auth/v1/token?grant_type=password';
  static const supabaseGoogleIdTokenUrl =
      '$supabaseUrl/auth/v1/token?grant_type=id_token';
  static const supabaseAuthUserUrl = '$supabaseUrl/auth/v1/user';
  /// Web client ID configured in Supabase Google provider (shared with rider app).
  static const googleWebClientId =
      '938128200725-r1e4f3n7gvsk5mfqvqs28if0gdktrj89.apps.googleusercontent.com';
  /// iOS OAuth client from driver GoogleService-Info.plist (CLIENT_ID).
  static const googleIosClientId =
      '938128200725-fh2piqepup7q21k3cbdmeheh4b6v4tqr.apps.googleusercontent.com';
  static const defaultCountryCode = '+974';
}
