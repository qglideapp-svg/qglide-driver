package com.alphatecks.driver

import android.content.Intent
import android.os.Bundle
import com.alphatecks.driver.messaging.RideRequestNotifications
import com.alphatecks.driver.messaging.RideRequestPayload
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleRideRequestIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleRideRequestIntent(intent)
    }

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

                "showRideRequestNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val payload = args?.let { RideRequestPayload.fromData(it) }
                    if (payload == null) {
                        result.success(false)
                    } else {
                        RideRequestNotifications.show(this, payload)
                        result.success(true)
                    }
                }

                "wasNativeRideRequestRecentlyShown" -> {
                    val args = call.arguments as? Map<*, *>
                    val rideId = args?.get("rideId")?.toString().orEmpty()
                    result.success(wasNativeRideRequestRecentlyShown(rideId))
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun handleRideRequestIntent(intent: Intent?) {
        if (intent == null) return

        val action = intent.getStringExtra(RideRequestNotifications.EXTRA_NOTIFICATION_ACTION)
        if (action == RideRequestNotifications.ACTION_ACCEPT) {
            return
        }

        val rideId = intent.getStringExtra(RideRequestNotifications.EXTRA_RIDE_ID).orEmpty()
        if (rideId.isEmpty()) return

        val payload = RideRequestPayload(
            rideId = rideId,
            pickupAddress = intent.getStringExtra(RideRequestNotifications.EXTRA_PICKUP).orEmpty(),
            dropoffAddress = intent.getStringExtra(RideRequestNotifications.EXTRA_DROPOFF).orEmpty(),
            riderName = intent.getStringExtra(RideRequestNotifications.EXTRA_RIDER_NAME),
            title = intent.getStringExtra(RideRequestNotifications.EXTRA_TITLE).orEmpty(),
            body = intent.getStringExtra(RideRequestNotifications.EXTRA_BODY).orEmpty(),
        )

        stashPendingOpen(payload)
        setOpenHomeFlag()
    }

    private fun stashPendingOpen(payload: RideRequestPayload) {
        try {
            val dataJson = JSONObject()
            payload.toDataMap().forEach { (key, value) -> dataJson.put(key, value) }

            getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                .edit()
                .putString(PENDING_OPEN_KEY, dataJson.toString())
                .commit()
        } catch (_: Exception) {
        }
    }

    private fun setOpenHomeFlag() {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .putBoolean(OPEN_HOME_KEY, true)
            .commit()
    }

    private fun wasNativeRideRequestRecentlyShown(rideId: String): Boolean {
        if (rideId.isEmpty()) return false
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val shownAt = prefs.getLong("$NATIVE_RIDE_ALERT_SHOWN_PREFIX$rideId", 0L)
        if (shownAt <= 0L) return false
        return System.currentTimeMillis() - shownAt < NATIVE_RIDE_ALERT_DEDUPE_MS
    }

    companion object {
        private const val RIDE_NOTIFICATIONS_CHANNEL =
            "com.alphatecks.driver/ride_notifications"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PENDING_OPEN_KEY = "flutter.pending_ride_notification_open"
        private const val OPEN_HOME_KEY = "flutter.should_open_home_for_ride_launch"
        private const val NATIVE_RIDE_ALERT_SHOWN_PREFIX = "flutter.native_ride_alert_shown_"
        private const val NATIVE_RIDE_ALERT_DEDUPE_MS = 40_000L
    }
}
