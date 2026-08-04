import Foundation
import UserNotifications

enum RideRequestNotifications {
  static let categoryId = "driver_ride_request_actions"
  static let actionAccept = "ride_accept"
  static let actionIgnore = "ride_ignore"
  static let payloadKey = "ride_request_payload_json"

  private static let prefsSuite = UserDefaults.standard
  private static let pendingActionKey = "flutter.pending_ride_notification_action"
  private static let pendingOpenKey = "flutter.pending_ride_notification_open"
  private static let openHomeKey = "flutter.should_open_home_for_ride_launch"
  private static let dedupePrefix = "flutter.native_ride_alert_shown_"
  private static let dedupeWindowSeconds: TimeInterval = 40

  static func handleRemoteNotification(userInfo: [AnyHashable: Any]) -> Bool {
    guard let payload = RideRequestPayload.from(userInfo: userInfo) else { return false }
    return show(payload: payload)
  }

  @discardableResult
  static func show(payload: RideRequestPayload) -> Bool {
    if wasRecentlyShown(rideId: payload.rideId) {
      return true
    }
    markShown(rideId: payload.rideId)

    let content = UNMutableNotificationContent()
    content.title = payload.title
    content.body = payload.body
    content.categoryIdentifier = categoryId
    content.sound = UNNotificationSound(named: UNNotificationSoundName("ride_request_alert.wav"))
    content.userInfo = buildNotificationUserInfo(payload: payload)

    let request = UNNotificationRequest(
      identifier: notificationIdentifier(for: payload.rideId),
      content: content,
      trigger: nil
    )

    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        NSLog("RideRequestNotifications: failed to post alert for \(payload.rideId): \(error.localizedDescription)")
      } else {
        NSLog("RideRequestNotifications: posted native ride-request alert \(payload.rideId)")
      }
    }
    return true
  }

  static func cancel(rideId: String) {
    guard !rideId.isEmpty else { return }
    UNUserNotificationCenter.current().removeDeliveredNotifications(
      withIdentifiers: [notificationIdentifier(for: rideId)]
    )
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: [notificationIdentifier(for: rideId)]
    )
  }

  static func handleNotificationResponse(_ response: UNNotificationResponse) -> Bool {
    let userInfo = response.notification.request.content.userInfo
    guard let payload = decodePayload(from: userInfo) ?? RideRequestPayload.from(userInfo: userInfo) else {
      return false
    }

    cancel(rideId: payload.rideId)

    switch response.actionIdentifier {
    case actionAccept:
      stashPendingAction(action: actionAccept, payload: payload)
      setOpenHomeFlag()
      RideResponseApi.respond(rideId: payload.rideId, action: "accept")
      return true

    case actionIgnore:
      RideResponseApi.respond(rideId: payload.rideId, action: "decline")
      return true

    case UNNotificationDefaultActionIdentifier:
      stashPendingOpen(payload: payload)
      setOpenHomeFlag()
      return true

    default:
      return false
    }
  }

  static func stashPendingAction(action: String, payload: RideRequestPayload) {
    let data = payload.toDataMap()
    let wrapper: [String: Any] = [
      "action": action,
      "data": data,
    ]
    guard let json = try? JSONSerialization.data(withJSONObject: wrapper),
          let raw = String(data: json, encoding: .utf8) else { return }
    prefsSuite.set(raw, forKey: pendingActionKey)
  }

  static func stashPendingOpen(payload: RideRequestPayload) {
    let data = payload.toDataMap()
    guard let json = try? JSONSerialization.data(withJSONObject: data),
          let raw = String(data: json, encoding: .utf8) else { return }
    prefsSuite.set(raw, forKey: pendingOpenKey)
    setOpenHomeFlag()
  }

  static func setOpenHomeFlag() {
    prefsSuite.set(true, forKey: openHomeKey)
  }

  private static func buildNotificationUserInfo(payload: RideRequestPayload) -> [AnyHashable: Any] {
    var info: [AnyHashable: Any] = payload.toDataMap()
    if let json = try? JSONSerialization.data(withJSONObject: payload.toDataMap()),
       let raw = String(data: json, encoding: .utf8) {
      info[payloadKey] = raw
    }
    info["type"] = "new_ride_request"
    info["target_user_type"] = "driver"
    info["ride_id"] = payload.rideId
    return info
  }

  private static func decodePayload(from userInfo: [AnyHashable: Any]) -> RideRequestPayload? {
    guard let raw = userInfo[payloadKey] as? String,
          let data = raw.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
      return nil
    }
    var map: [AnyHashable: Any] = json
    return RideRequestPayload.from(userInfo: map)
  }

  private static func notificationIdentifier(for rideId: String) -> String {
    "ride_request_\(rideId)"
  }

  private static func dedupeKey(for rideId: String) -> String {
    "\(dedupePrefix)\(rideId)"
  }

  private static func wasRecentlyShown(rideId: String) -> Bool {
    let key = dedupeKey(for: rideId)
    let shownAt = prefsSuite.double(forKey: key)
    if shownAt <= 0 { return false }
    return Date().timeIntervalSince1970 - shownAt < dedupeWindowSeconds
  }

  private static func markShown(rideId: String) {
    prefsSuite.set(Date().timeIntervalSince1970, forKey: dedupeKey(for: rideId))
  }
}
