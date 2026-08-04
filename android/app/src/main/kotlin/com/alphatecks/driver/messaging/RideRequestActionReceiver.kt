package com.alphatecks.driver.messaging

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.alphatecks.driver.MainActivity
import org.json.JSONObject

class RideRequestActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val rideId = intent.getStringExtra(RideRequestNotifications.EXTRA_RIDE_ID).orEmpty()
        if (rideId.isEmpty()) return

        val action = intent.action.orEmpty()
        val payload = RideRequestPayload(
            rideId = rideId,
            pickupAddress = intent.getStringExtra(RideRequestNotifications.EXTRA_PICKUP).orEmpty(),
            dropoffAddress = intent.getStringExtra(RideRequestNotifications.EXTRA_DROPOFF).orEmpty(),
            riderName = intent.getStringExtra(RideRequestNotifications.EXTRA_RIDER_NAME),
            title = intent.getStringExtra(RideRequestNotifications.EXTRA_TITLE).orEmpty(),
            body = intent.getStringExtra(RideRequestNotifications.EXTRA_BODY).orEmpty(),
        )

        RideRequestNotifications.cancel(context, rideId)

        when (action) {
            RideRequestNotifications.ACTION_ACCEPT -> {
                Log.d(TAG, "Accept tapped for ride $rideId")
                stashPendingAction(context, RideRequestNotifications.ACTION_ACCEPT, payload)
                setOpenHomeFlag(context)
                RideResponseApi.respond(context, rideId, "accept")
                launchMainActivity(context, rideId, RideRequestNotifications.ACTION_ACCEPT)
            }

            RideRequestNotifications.ACTION_DECLINE -> {
                Log.d(TAG, "Decline tapped for ride $rideId")
                RideResponseApi.respond(context, rideId, "decline")
            }
        }
    }

    private fun stashPendingAction(
        context: Context,
        action: String,
        payload: RideRequestPayload,
    ) {
        try {
            val dataJson = JSONObject()
            payload.toDataMap().forEach { (key, value) -> dataJson.put(key, value) }
            val wrapper = JSONObject()
                .put("action", action)
                .put("data", dataJson)

            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(PENDING_ACTION_KEY, wrapper.toString())
                .apply()
        } catch (error: Exception) {
            Log.w(TAG, "Failed to stash pending ride action", error)
        }
    }

    private fun setOpenHomeFlag(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(OPEN_HOME_KEY, true)
            .apply()
    }

    private fun launchMainActivity(context: Context, rideId: String, action: String) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(RideRequestNotifications.EXTRA_RIDE_ID, rideId)
            putExtra(RideRequestNotifications.EXTRA_NOTIFICATION_ACTION, action)
        }
        context.startActivity(launchIntent)
    }

    companion object {
        private const val TAG = "RideRequestActionReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        const val PENDING_ACTION_KEY = "flutter.pending_ride_notification_action"
        const val OPEN_HOME_KEY = "flutter.should_open_home_for_ride_launch"
    }
}
