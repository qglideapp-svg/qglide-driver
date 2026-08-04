package com.alphatecks.driver.messaging

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object RideResponseApi {
    private const val TAG = "RideResponseApi"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val ACCESS_TOKEN_KEY = "flutter.access_token"
    private const val RIDE_RESPONSE_URL =
        "https://bvazoowmmiymbbhxoggo.supabase.co/functions/v1/ride-response"

    fun respond(context: Context, rideId: String, action: String) {
        Thread {
            try {
                val token = readAccessToken(context) ?: return@Thread
                val payload = JSONObject()
                    .put("ride_id", rideId)
                    .put("action", action)

                val connection = (URL(RIDE_RESPONSE_URL).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 30_000
                    readTimeout = 30_000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Authorization", "Bearer $token")
                }

                connection.outputStream.use { stream ->
                    stream.write(payload.toString().toByteArray(Charsets.UTF_8))
                }

                val code = connection.responseCode
                if (code !in 200..299) {
                    Log.w(TAG, "ride-response failed with HTTP $code for ride $rideId action $action")
                }
                connection.disconnect()
            } catch (error: Exception) {
                Log.w(TAG, "ride-response network error for ride $rideId", error)
            }
        }.start()
    }

    private fun readAccessToken(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(ACCESS_TOKEN_KEY, null)?.takeIf { it.isNotEmpty() }
    }
}
