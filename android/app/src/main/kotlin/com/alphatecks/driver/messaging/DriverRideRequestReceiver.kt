package com.alphatecks.driver.messaging

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.RemoteMessage

/**
 * Runs before Flutter's FCM receiver and posts native ride-request notifications
 * with Accept/Cancel action buttons immediately when a push arrives.
 */
class DriverRideRequestReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.extras == null) return

        val remoteMessage = RemoteMessage(intent.extras)
        if (!RideRequestNotifications.isRideRequest(remoteMessage)) return

        Log.d(TAG, "Ride request FCM received — showing native Accept/Cancel notification")
        RideRequestNotifications.show(context, remoteMessage)
        RideRequestNotifications.cancelFcmDefaultNotification(context, remoteMessage)
    }

    companion object {
        private const val TAG = "DriverRideRequestReceiver"
    }
}
