import Foundation

struct RideRequestPayload {
  let rideId: String
  let pickupAddress: String
  let dropoffAddress: String
  let riderName: String?
  let title: String
  let body: String

  func toDataMap() -> [String: String] {
    var map: [String: String] = [
      "type": "new_ride_request",
      "target_user_type": "driver",
      "ride_id": rideId,
      "pickup_address": pickupAddress,
      "dropoff_address": dropoffAddress,
    ]
    if let riderName, !riderName.isEmpty {
      map["rider_name"] = riderName
    }
    return map
  }

  private static let titlePattern = try! NSRegularExpression(pattern: "^New ride request from .+$")
  private static let bodyPattern = try! NSRegularExpression(pattern: "^Pickup at .+ → .+$")
  private static let riderPattern = try! NSRegularExpression(pattern: "^New ride request from (.+)$")
  private static let routePattern = try! NSRegularExpression(pattern: "^Pickup at (.+) → (.+)$")

  static func from(userInfo: [AnyHashable: Any]) -> RideRequestPayload? {
    let data = flattenFcmData(userInfo)
    guard isForDriver(data) else { return nil }
    guard !isIncomingCall(data) else { return nil }

    let type = normalized(data["type"]) ?? normalized(data["notification_type"])
    if type == "new_ride_request" {
      return build(data: data, notificationTitle: nil, notificationBody: nil)
    }

    let rideId = normalized(data["ride_id"]) ?? normalized(data["id"]) ?? ""
    if !rideId.isEmpty {
      let status = normalized(data["status"]) ?? ""
      if status.isEmpty || status == "requested" || status == "pending" {
        return build(data: data, notificationTitle: nil, notificationBody: nil)
      }
    }

    let title = normalized(data["notification_title"])
      ?? normalized(data["title"]) ?? ""
    let body = normalized(data["notification_body"])
      ?? normalized(data["body"])
      ?? normalized(data["message"]) ?? ""

    if !title.isEmpty && looksLikeTitle(title) {
      return build(data: data, notificationTitle: title, notificationBody: body)
    }
    if !body.isEmpty && matches(bodyPattern, in: body) {
      return build(data: data, notificationTitle: title, notificationBody: body)
    }

    return nil
  }

  private static func build(
    data: [String: String],
    notificationTitle: String?,
    notificationBody: String?
  ) -> RideRequestPayload? {
    let rideId = normalized(data["ride_id"]) ?? normalized(data["id"]) ?? ""
    if rideId.isEmpty { return nil }

    var pickup = normalized(data["pickup_address"]) ?? ""
    var dropoff = normalized(data["dropoff_address"]) ?? ""
    var riderName = normalized(data["rider_name"])

    let resolvedTitle = notificationTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
      ?? normalized(data["notification_title"])
      ?? normalized(data["title"]) ?? ""
    let resolvedBody = notificationBody?.trimmingCharacters(in: .whitespacesAndNewlines)
      ?? normalized(data["notification_body"])
      ?? normalized(data["body"])
      ?? normalized(data["message"]) ?? ""

    if !resolvedTitle.isEmpty,
       let match = firstMatch(riderPattern, in: resolvedTitle),
       match.count > 1 {
      let name = (resolvedTitle as NSString).substring(with: match[1]).trimmingCharacters(in: .whitespacesAndNewlines)
      if !name.isEmpty { riderName = name }
    }

    if !resolvedBody.isEmpty,
       let match = firstMatch(routePattern, in: resolvedBody),
       match.count > 2 {
      if pickup.isEmpty {
        pickup = (resolvedBody as NSString).substring(with: match[1]).trimmingCharacters(in: .whitespacesAndNewlines)
      }
      if dropoff.isEmpty {
        dropoff = (resolvedBody as NSString).substring(with: match[2]).trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }

    let title: String
    if !resolvedTitle.isEmpty {
      title = resolvedTitle
    } else if let riderName, !riderName.isEmpty {
      title = "New ride request from \(riderName)"
    } else {
      title = "New ride request"
    }

    let body: String
    if !pickup.isEmpty || !dropoff.isEmpty {
      body = "Pickup at \(pickup.isEmpty ? "—" : pickup) → \(dropoff.isEmpty ? "—" : dropoff)"
    } else if !resolvedBody.isEmpty {
      body = resolvedBody
    } else {
      body = "Open the app to review this ride request."
    }

    return RideRequestPayload(
      rideId: rideId,
      pickupAddress: pickup,
      dropoffAddress: dropoff,
      riderName: riderName,
      title: title,
      body: body
    )
  }

  private static func flattenFcmData(_ userInfo: [AnyHashable: Any]) -> [String: String] {
    var data: [String: String] = [:]
    for (key, value) in userInfo {
      guard let keyString = key as? String else { continue }
      if keyString.hasPrefix("google.") || keyString.hasPrefix("gcm.") || keyString == "aps" {
        continue
      }
      if let stringValue = value as? String {
        data[keyString] = stringValue
      } else if let numberValue = value as? NSNumber {
        data[keyString] = numberValue.stringValue
      }
    }
    return data
  }

  private static func isForDriver(_ data: [String: String]) -> Bool {
    let target = normalized(data["target_user_type"]) ?? ""
    if target.isEmpty || target == "all" { return true }
    return target == "driver"
  }

  private static func isIncomingCall(_ data: [String: String]) -> Bool {
    let type = normalized(data["type"])
      ?? normalized(data["notification_type"])
      ?? normalized(data["call_type"]) ?? ""
    return type == "incoming_call"
  }

  private static func looksLikeTitle(_ title: String) -> Bool {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed == "New ride request" || trimmed == "New ride request with stop(s)" {
      return true
    }
    return matches(titlePattern, in: trimmed)
  }

  private static func normalized(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func matches(_ regex: NSRegularExpression, in text: String) -> Bool {
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.firstMatch(in: text, range: range) != nil
  }

  private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> [NSRange]? {
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range) else { return nil }
    return (0..<match.numberOfRanges).map { match.range(at: $0) }
  }
}
