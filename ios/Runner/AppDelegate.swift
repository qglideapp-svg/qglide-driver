import Flutter
import GoogleMaps
import UIKit
import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate, FlutterImplicitEngineDelegate {
  private let rideRequestCategoryId = "driver_ride_request_actions"
  private let rideAcceptActionId = "ride_accept"
  private let rideIgnoreActionId = "ride_ignore"
  private let rideNotificationsChannelName = "com.alphatecks.driver/ride_notifications"

  private var rideNotificationsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GMSServices.provideAPIKey("AIzaSyBrThzOJlW4SbyUHKLoCrv9yK5AAs_esao")

    if #available(iOS 10.0, *) {
      registerRideRequestNotificationCategory()
      UNUserNotificationCenter.current().delegate = self
    }
    Messaging.messaging().delegate = self

    DispatchQueue.main.async {
      application.registerForRemoteNotifications()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    SwiftFlutterForegroundTaskPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: rideNotificationsChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "cancelRideRequest":
        let rideId = (call.arguments as? [String: Any])?["rideId"] as? String ?? ""
        RideRequestNotifications.cancel(rideId: rideId)
        result(nil)
      case "registerForRemoteNotifications":
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
        result(nil)
      case "wasNativeRideRequestRecentlyShown":
        let rideId = (call.arguments as? [String: Any])?["rideId"] as? String ?? ""
        let key = "flutter.native_ride_alert_shown_\(rideId)"
        let shownAt = UserDefaults.standard.double(forKey: key)
        let recentlyShown = shownAt > 0
          && Date().timeIntervalSince1970 - shownAt < 40
        result(recentlyShown)
      case "showRideRequestNotification":
        guard let args = call.arguments as? [String: Any],
              let payload = RideRequestPayload.from(userInfo: args) else {
          result(false)
          return
        }
        result(RideRequestNotifications.show(payload: payload))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    rideNotificationsChannel = channel
  }

  @available(iOS 10.0, *)
  private func registerRideRequestNotificationCategory() {
    let accept = UNNotificationAction(
      identifier: rideAcceptActionId,
      title: "Accept",
      options: [.foreground]
    )
    let cancel = UNNotificationAction(
      identifier: rideIgnoreActionId,
      title: "Cancel",
      options: [.destructive]
    )
    let category = UNNotificationCategory(
      identifier: rideRequestCategoryId,
      actions: [accept, cancel],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    passApnsTokenToFirebaseAuth(deviceToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs registration failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }

    let handledRideRequest = RideRequestNotifications.handleRemoteNotification(userInfo: userInfo)

    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: { result in
        completionHandler(handledRideRequest ? .newData : result)
      }
    )
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let fcmToken, !fcmToken.isEmpty else { return }
    DispatchQueue.main.async { [weak self] in
      self?.rideNotificationsChannel?.invokeMethod("onFcmTokenRefresh", arguments: fcmToken)
    }
  }

  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    if RideRequestPayload.from(userInfo: userInfo) != nil {
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .list, .sound])
      } else {
        completionHandler([.alert, .sound])
      }
      return
    }
    super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if RideRequestNotifications.handleNotificationResponse(response) {
      completionHandler()
      return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  private func passApnsTokenToFirebaseAuth(_ deviceToken: Data) {
#if DEBUG
    Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
#else
    Auth.auth().setAPNSToken(deviceToken, type: .prod)
#endif
  }
}
