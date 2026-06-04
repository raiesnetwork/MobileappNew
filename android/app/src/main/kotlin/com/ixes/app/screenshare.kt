package com.ixes.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

class ScreenShareService : Service() {

    companion object {
        private const val TAG = "ScreenShareService"
        private const val CHANNEL_ID = "screen_share_channel"
        private const val NOTIFICATION_ID = 1001
    }

    private var isStarted = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // ✅ FIX: Ensure we only start once (prevents duplicate service starts)
        if (isStarted) {
            Log.d(TAG, "⚠️ Already started, ignoring duplicate call")
            return START_NOT_STICKY
        }

        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Screen Sharing Active")
            .setContentText("Ixes is sharing your screen")
            .setSmallIcon(android.R.drawable.ic_menu_slideshow)
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_LOW)
            .build()

        try {
            // ✅ CRITICAL: Call startForeground IMMEDIATELY in onStartCommand
            // This MUST happen before flutter_webrtc calls MediaProjection.start()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Android 14+ (targetSDK 34+): MUST specify MEDIA_PROJECTION type
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
                Log.d(TAG, "✅ FGS Started (Android 14+) with MEDIA_PROJECTION type")
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10-13: Type can be specified but not required
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
                Log.d(TAG, "✅ FGS Started (Android 10-13) with MEDIA_PROJECTION type")
            } else {
                // Android 9 and below: No type parameter needed
                @Suppress("DEPRECATION")
                startForeground(NOTIFICATION_ID, notification)
                Log.d(TAG, "✅ FGS Started (Android 9-) without type")
            }
            isStarted = true
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ SecurityException in startForeground: ${e.message}")
            Log.e(TAG, "⚠️ Check if FOREGROUND_SERVICE_MEDIA_PROJECTION permission is granted in AndroidManifest.xml")
            stopSelf()
            return START_NOT_STICKY
        } catch (e: Exception) {
            Log.e(TAG, "❌ Unexpected error in startForeground: ${e.message}")
            e.printStackTrace()
            stopSelf()
            return START_NOT_STICKY
        }

        // ✅ FIX: Return START_NOT_STICKY to prevent auto-restart on crash
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Sharing",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Used while screen sharing is active"
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isStarted = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping foreground: ${e.message}")
        }
        Log.d(TAG, "🛑 ScreenShareService destroyed")
        super.onDestroy()
    }
}
