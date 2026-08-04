import Foundation

enum RideResponseApi {
  private static let accessTokenKey = "flutter.access_token"
  private static let rideResponseUrl =
    "https://bvazoowmmiymbbhxoggo.supabase.co/functions/v1/ride-response"

  static func respond(rideId: String, action: String) {
    DispatchQueue.global(qos: .utility).async {
      guard let token = readAccessToken(), !token.isEmpty else {
        NSLog("RideResponseApi: missing access token for ride \(rideId)")
        return
      }

      guard let url = URL(string: rideResponseUrl) else { return }

      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.timeoutInterval = 30
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

      let payload: [String: String] = [
        "ride_id": rideId,
        "action": action,
      ]

      do {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
      } catch {
        NSLog("RideResponseApi: failed to encode payload: \(error.localizedDescription)")
        return
      }

      let task = URLSession.shared.dataTask(with: request) { _, response, error in
        if let error {
          NSLog("RideResponseApi: network error for ride \(rideId): \(error.localizedDescription)")
          return
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
          NSLog("RideResponseApi: HTTP \(http.statusCode) for ride \(rideId) action \(action)")
        }
      }
      task.resume()
    }
  }

  private static func readAccessToken() -> String? {
    UserDefaults.standard.string(forKey: accessTokenKey)
  }
}
