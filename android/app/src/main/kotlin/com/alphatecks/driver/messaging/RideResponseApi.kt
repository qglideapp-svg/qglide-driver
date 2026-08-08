package com.alphatecks.driver.messaging

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object RideResponseApi {
    private const val TAG = "RideResponseApi"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val NATIVE_ACCESS_TOKEN_KEY = "flutter.native_notification_access_token"
    private const val LEGACY_ACCESS_TOKEN_KEY = "flutter.access_token"
    private const val RIDE_RESPONSE_URL =
        "https://bvazoowmmiymbbhxoggo.supabase.co/functions/v1/ride-response"
    private const val SUPABASE_ANON_KEY =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2YXpvb3dtbWl5bWJiaHhvZ2dvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2OTQzMjQsImV4cCI6MjA3NTI3MDMyNH0.9vdJHTTnW38CctYwD9GZOvoX_SEu58FLu81mbjQFBdk"

    fun respond(context: Context, rideId: String, action: String) {
        val latch = CountDownLatch(1)
        Thread {
            try {
                respondSync(context, rideId, action)
            } finally {
                latch.countDown()
            }
        }.start()

        // Give OEM background handlers (Vivo/Funtouch) a moment to finish the HTTP call.
        try {
            latch.await(12, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            Log.w(TAG, "ride-response timed out waiting for ride $rideId action $action")
        }
    }

    private fun respondSync(context: Context, rideId: String, action: String) {
        try {
            val token = readAccessToken(context)
            if (token == null) {
                Log.w(TAG, "No access token available for ride $rideId action $action")
                return
            }

            val payload = JSONObject()
                .put("ride_id", rideId)
                .put("action", action)

            val connection = (URL(RIDE_RESPONSE_URL).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 30_000
                readTimeout = 30_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("apikey", SUPABASE_ANON_KEY)
                setRequestProperty("Authorization", "Bearer $token")
            }

            connection.outputStream.use { stream ->
                stream.write(payload.toString().toByteArray(Charsets.UTF_8))
            }

            val code = connection.responseCode
            if (code !in 200..299) {
                val errorBody = try {
                    connection.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                } catch (_: Exception) {
                    ""
                }
                Log.w(
                    TAG,
                    "ride-response failed with HTTP $code for ride $rideId action $action: $errorBody",
                )
            } else {
                Log.d(TAG, "ride-response succeeded for ride $rideId action $action")
            }
            connection.disconnect()
        } catch (error: Exception) {
            Log.w(TAG, "ride-response network error for ride $rideId", error)
        }
    }

    private fun readAccessToken(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(NATIVE_ACCESS_TOKEN_KEY, null)
            ?.takeIf { it.isNotEmpty() }
            ?: prefs.getString(LEGACY_ACCESS_TOKEN_KEY, null)?.takeIf { it.isNotEmpty() }
    }
}
