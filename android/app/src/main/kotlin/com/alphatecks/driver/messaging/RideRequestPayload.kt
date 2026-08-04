package com.alphatecks.driver.messaging

import com.google.firebase.messaging.RemoteMessage

data class RideRequestPayload(
    val rideId: String,
    val pickupAddress: String,
    val dropoffAddress: String,
    val riderName: String?,
    val title: String,
    val body: String,
) {
    fun toDataMap(): Map<String, String> {
        val map = linkedMapOf(
            "type" to "new_ride_request",
            "target_user_type" to "driver",
            "ride_id" to rideId,
            "pickup_address" to pickupAddress,
            "dropoff_address" to dropoffAddress,
        )
        riderName?.takeIf { it.isNotEmpty() }?.let { map["rider_name"] = it }
        return map
    }

    companion object {
        private val titlePattern = Regex("^New ride request from .+$")
        private val bodyPattern = Regex("^Pickup at .+ → .+$")
        private val riderPattern = Regex("^New ride request from (.+)$")
        private val routePattern = Regex("^Pickup at (.+) → (.+)$")

        fun from(remoteMessage: RemoteMessage): RideRequestPayload? {
            if (!isForDriver(remoteMessage.data)) return null
            if (isIncomingCall(remoteMessage.data)) return null

            val data = remoteMessage.data
            val notification = remoteMessage.notification

            val type = data["type"]?.lowercase()?.trim()
                ?: data["notification_type"]?.lowercase()?.trim()
            if (type == "new_ride_request") {
                return build(data, notification?.title, notification?.body)
            }

            val rideId = data["ride_id"]?.trim().orEmpty().ifEmpty { data["id"]?.trim().orEmpty() }
            if (rideId.isNotEmpty()) {
                val status = data["status"]?.lowercase()?.trim().orEmpty()
                if (status.isEmpty() || status == "requested" || status == "pending") {
                    return build(data, notification?.title, notification?.body)
                }
            }

            val title = notification?.title?.trim().orEmpty()
                .ifEmpty { data["title"]?.trim().orEmpty() }
                .ifEmpty { data["notification_title"]?.trim().orEmpty() }
            val body = notification?.body?.trim().orEmpty()
                .ifEmpty { data["body"]?.trim().orEmpty() }
                .ifEmpty { data["message"]?.trim().orEmpty() }
                .ifEmpty { data["notification_body"]?.trim().orEmpty() }

            if (title.isNotEmpty() && looksLikeTitle(title)) {
                return build(data, title, body)
            }
            if (body.isNotEmpty() && bodyPattern.matches(body.trim())) {
                return build(data, title, body)
            }

            return null
        }

        fun isRideRequest(remoteMessage: RemoteMessage): Boolean = from(remoteMessage) != null

        private fun build(
            data: Map<String, String>,
            notificationTitle: String?,
            notificationBody: String?,
        ): RideRequestPayload? {
            val rideId = data["ride_id"]?.trim().orEmpty().ifEmpty { data["id"]?.trim().orEmpty() }
            if (rideId.isEmpty()) return null

            var pickup = data["pickup_address"]?.trim().orEmpty()
            var dropoff = data["dropoff_address"]?.trim().orEmpty()
            var riderName = data["rider_name"]?.trim()

            val resolvedTitle = notificationTitle?.trim().orEmpty()
                .ifEmpty { data["notification_title"]?.trim().orEmpty() }
            val resolvedBody = notificationBody?.trim().orEmpty()
                .ifEmpty { data["notification_body"]?.trim().orEmpty() }
                .ifEmpty { data["body"]?.trim().orEmpty() }
                .ifEmpty { data["message"]?.trim().orEmpty() }

            if (resolvedTitle.isNotEmpty()) {
                riderPattern.find(resolvedTitle)?.groupValues?.getOrNull(1)?.trim()?.let {
                    if (!it.isEmpty()) riderName = it
                }
            }

            if (resolvedBody.isNotEmpty()) {
                routePattern.find(resolvedBody)?.let { match ->
                    if (pickup.isEmpty()) pickup = match.groupValues[1].trim()
                    if (dropoff.isEmpty()) dropoff = match.groupValues[2].trim()
                }
            }

            val title = when {
                resolvedTitle.isNotEmpty() -> resolvedTitle
                !riderName.isNullOrEmpty() -> "New ride request from $riderName"
                else -> "New ride request"
            }
            val body = when {
                pickup.isNotEmpty() || dropoff.isNotEmpty() ->
                    "Pickup at ${pickup.ifEmpty { "—" }} → ${dropoff.ifEmpty { "—" }}"
                resolvedBody.isNotEmpty() -> resolvedBody
                else -> "Open the app to review this ride request."
            }

            return RideRequestPayload(
                rideId = rideId,
                pickupAddress = pickup,
                dropoffAddress = dropoff,
                riderName = riderName,
                title = title,
                body = body,
            )
        }

        private fun isForDriver(data: Map<String, String>): Boolean {
            val target = data["target_user_type"]?.lowercase()?.trim().orEmpty()
            if (target.isEmpty() || target == "all") return true
            return target == "driver"
        }

        private fun isIncomingCall(data: Map<String, String>): Boolean {
            val type = data["type"] ?: data["notification_type"] ?: data["call_type"]
            return type?.lowercase()?.trim() == "incoming_call"
        }

        private fun looksLikeTitle(title: String): Boolean {
            val trimmed = title.trim()
            return trimmed == "New ride request" ||
                trimmed == "New ride request with stop(s)" ||
                titlePattern.matches(trimmed)
        }
    }
}
