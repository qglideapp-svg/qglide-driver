package com.alphatecks.driver.messaging

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import com.alphatecks.driver.MainActivity
import org.json.JSONObject

/**
 * Transparent trampoline for notification Accept/Cancel actions.
 *
 * Vivo, Oppo, and other OEMs often block [BroadcastReceiver] handlers for
 * notification actions when the app is backgrounded. Starting a short-lived
 * activity is significantly more reliable.
 */
class RideRequestActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }

        val rideId = intent.getStringExtra(RideRequestNotifications.EXTRA_RIDE_ID).orEmpty()
        val action = intent.action.orEmpty()
        if (rideId.isEmpty() || action.isEmpty()) {
            Log.w(TAG, "Missing ride action payload")
            finish()
            return
        }

        val payload = RideRequestPayload(
            rideId = rideId,
            pickupAddress = intent.getStringExtra(RideRequestNotifications.EXTRA_PICKUP).orEmpty(),
            dropoffAddress = intent.getStringExtra(RideRequestNotifications.EXTRA_DROPOFF).orEmpty(),
            riderName = intent.getStringExtra(RideRequestNotifications.EXTRA_RIDER_NAME),
            title = intent.getStringExtra(RideRequestNotifications.EXTRA_TITLE).orEmpty(),
            body = intent.getStringExtra(RideRequestNotifications.EXTRA_BODY).orEmpty(),
        )

        RideRequestNotifications.cancel(this, rideId)

        when (action) {
            RideRequestNotifications.ACTION_ACCEPT -> {
                Log.d(TAG, "Accept tapped for ride $rideId")
                RideResponseApi.respond(this, rideId, "accept")
                stashPendingAction(RideRequestNotifications.ACTION_ACCEPT, payload)
                setOpenHomeFlag()
                launchMainActivity(rideId, RideRequestNotifications.ACTION_ACCEPT)
            }

            RideRequestNotifications.ACTION_DECLINE -> {
                Log.d(TAG, "Decline tapped for ride $rideId")
                RideResponseApi.respond(this, rideId, "decline")
            }

            else -> Log.w(TAG, "Unknown ride action: $action")
        }

        finish()
    }

    private fun stashPendingAction(action: String, payload: RideRequestPayload) {
        try {
            val dataJson = JSONObject()
            payload.toDataMap().forEach { (key, value) -> dataJson.put(key, value) }
            val wrapper = JSONObject()
                .put("action", action)
                .put("data", dataJson)

            getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                .edit()
                .putString(PENDING_ACTION_KEY, wrapper.toString())
                .commit()
        } catch (error: Exception) {
            Log.w(TAG, "Failed to stash pending ride action", error)
        }
    }

    private fun setOpenHomeFlag() {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .putBoolean(OPEN_HOME_KEY, true)
            .commit()
    }

    private fun launchMainActivity(rideId: String, action: String) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            putExtra(RideRequestNotifications.EXTRA_RIDE_ID, rideId)
            putExtra(RideRequestNotifications.EXTRA_NOTIFICATION_ACTION, action)
        }
        startActivity(launchIntent)
    }

    companion object {
        private const val TAG = "RideRequestActionActivity"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        const val PENDING_ACTION_KEY = "flutter.pending_ride_notification_action"
        const val OPEN_HOME_KEY = "flutter.should_open_home_for_ride_launch"
    }
}
