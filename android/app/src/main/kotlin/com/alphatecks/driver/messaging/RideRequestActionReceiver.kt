package com.alphatecks.driver.messaging

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Legacy fallback for ride-request actions created before the trampoline
 * activity switch. Vivo/Funtouch devices should use [RideRequestActionActivity].
 */
class RideRequestActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        Thread {
            try {
                forwardToActivity(context, intent)
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    private fun forwardToActivity(context: Context, intent: Intent) {
        val rideId = intent.getStringExtra(RideRequestNotifications.EXTRA_RIDE_ID).orEmpty()
        if (rideId.isEmpty()) return

        val action = intent.action.orEmpty()
        val trampoline = Intent(context, RideRequestActionActivity::class.java).apply {
            this.action = action
            putExtra(RideRequestNotifications.EXTRA_RIDE_ID, rideId)
            putExtra(
                RideRequestNotifications.EXTRA_PICKUP,
                intent.getStringExtra(RideRequestNotifications.EXTRA_PICKUP).orEmpty(),
            )
            putExtra(
                RideRequestNotifications.EXTRA_DROPOFF,
                intent.getStringExtra(RideRequestNotifications.EXTRA_DROPOFF).orEmpty(),
            )
            putExtra(
                RideRequestNotifications.EXTRA_RIDER_NAME,
                intent.getStringExtra(RideRequestNotifications.EXTRA_RIDER_NAME),
            )
            putExtra(
                RideRequestNotifications.EXTRA_TITLE,
                intent.getStringExtra(RideRequestNotifications.EXTRA_TITLE).orEmpty(),
            )
            putExtra(
                RideRequestNotifications.EXTRA_BODY,
                intent.getStringExtra(RideRequestNotifications.EXTRA_BODY).orEmpty(),
            )
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            context.startActivity(trampoline)
        } catch (error: Exception) {
            Log.w(TAG, "Failed to forward legacy ride action", error)
        }
    }

    companion object {
        private const val TAG = "RideRequestActionReceiver"
    }
}
