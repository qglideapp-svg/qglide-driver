package com.alphatecks.driver.messaging

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.alphatecks.driver.MainActivity
import com.alphatecks.driver.R
import com.google.firebase.messaging.RemoteMessage

object RideRequestNotifications {
    private const val TAG = "RideRequestNotifications"

    const val CHANNEL_ID = "driver_ride_requests"
    private const val CHANNEL_NAME = "Ride Requests"

    const val ACTION_ACCEPT = "ride_accept"
    const val ACTION_DECLINE = "ride_ignore"

    const val EXTRA_RIDE_ID = "ride_id"
    const val EXTRA_PICKUP = "pickup_address"
    const val EXTRA_DROPOFF = "dropoff_address"
    const val EXTRA_RIDER_NAME = "rider_name"
    const val EXTRA_TITLE = "notification_title"
    const val EXTRA_BODY = "notification_body"
    const val EXTRA_NOTIFICATION_ACTION = "notification_action"

    fun isRideRequest(remoteMessage: RemoteMessage): Boolean =
        RideRequestPayload.isRideRequest(remoteMessage)

    fun show(context: Context, remoteMessage: RemoteMessage) {
        val payload = RideRequestPayload.from(remoteMessage) ?: return
        show(context, payload)
    }

    fun show(context: Context, payload: RideRequestPayload) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(context, manager)

        val notificationId = payload.rideId.hashCode()
        val contentIntent = PendingIntent.getActivity(
            context,
            notificationId,
            Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(EXTRA_RIDE_ID, payload.rideId)
                putExtra(EXTRA_PICKUP, payload.pickupAddress)
                putExtra(EXTRA_DROPOFF, payload.dropoffAddress)
                putExtra(EXTRA_RIDER_NAME, payload.riderName)
                putExtra(EXTRA_TITLE, payload.title)
                putExtra(EXTRA_BODY, payload.body)
            },
            pendingIntentFlags(),
        )

        val acceptIntent = actionPendingIntent(context, payload, ACTION_ACCEPT, notificationId + 1)
        val declineIntent = actionPendingIntent(context, payload, ACTION_DECLINE, notificationId + 2)

        val soundUri = Uri.parse(
            "android.resource://${context.packageName}/${R.raw.ride_request_alert}",
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(payload.title)
            .setContentText(payload.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(payload.body).setBigContentTitle(payload.title))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setOnlyAlertOnce(false)
            .setContentIntent(contentIntent)
            .setFullScreenIntent(contentIntent, true)
            .setSound(soundUri)
            .setDefaults(Notification.DEFAULT_VIBRATE or Notification.DEFAULT_LIGHTS)
            .setTimeoutAfter(40_000L)
            .addAction(
                R.drawable.ic_ride_action_accept,
                "Accept",
                acceptIntent,
            )
            .addAction(
                R.drawable.ic_ride_action_cancel,
                "Cancel",
                declineIntent,
            )
            .build()

        manager.notify(notificationId, notification)
        Log.d(TAG, "Posted native ride-request notification ${payload.rideId} with Accept/Cancel actions")
    }

    fun cancel(context: Context, rideId: String) {
        if (rideId.isEmpty()) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(rideId.hashCode())
    }

    fun cancelFcmDefaultNotification(context: Context, remoteMessage: RemoteMessage) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(0)
        remoteMessage.messageId?.let { messageId -> manager.cancel(messageId, 0) }
        remoteMessage.collapseKey?.let { collapseKey -> manager.cancel(collapseKey, 0) }
    }

    private fun actionPendingIntent(
        context: Context,
        payload: RideRequestPayload,
        action: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, RideRequestActionReceiver::class.java).apply {
            this.action = action
            putExtra(EXTRA_RIDE_ID, payload.rideId)
            putExtra(EXTRA_PICKUP, payload.pickupAddress)
            putExtra(EXTRA_DROPOFF, payload.dropoffAddress)
            putExtra(EXTRA_RIDER_NAME, payload.riderName)
            putExtra(EXTRA_TITLE, payload.title)
            putExtra(EXTRA_BODY, payload.body)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            pendingIntentFlags(),
        )
    }

    private fun ensureChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return

        val soundUri = Uri.parse(
            "android.resource://${context.packageName}/${R.raw.ride_request_alert}",
        )
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alerts when a new ride request is available"
            enableVibration(true)
            setSound(
                soundUri,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun pendingIntentFlags(): Int {
        val base = PendingIntent.FLAG_UPDATE_CURRENT
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            base or PendingIntent.FLAG_IMMUTABLE
        } else {
            base
        }
    }
}
