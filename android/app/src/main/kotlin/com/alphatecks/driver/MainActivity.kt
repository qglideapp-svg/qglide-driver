package com.alphatecks.driver

import com.alphatecks.driver.messaging.RideRequestNotifications
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RIDE_NOTIFICATIONS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "cancelRideRequest" -> {
                    val rideId = call.argument<String>("rideId").orEmpty()
                    RideRequestNotifications.cancel(this, rideId)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val RIDE_NOTIFICATIONS_CHANNEL =
            "com.alphatecks.driver/ride_notifications"
    }
}
