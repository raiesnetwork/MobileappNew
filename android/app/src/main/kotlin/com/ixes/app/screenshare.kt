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
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val channelId = "screen_share_channel"

        val channel = NotificationChannel(
            channelId,
            "Screen Sharing",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Used while screen sharing is active"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)

        val notification = Notification.Builder(this, channelId)
            .setContentTitle("Screen Sharing Active")
            .setContentText("Ixes is sharing your screen")
            .setSmallIcon(android.R.drawable.ic_menu_slideshow)
            .setOngoing(true)
            .build()

        when {
            // Android 14+ → BOTH mediaProjection + specialUse
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> {
                startForeground(
                    1001,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
                Log.d(TAG, "✅ Started with MEDIA_PROJECTION | SPECIAL_USE (Android 14+)")
            }
            // Android 10–13 → mediaProjection only
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                startForeground(
                    1001,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
                Log.d(TAG, "✅ Started with MEDIA_PROJECTION (Android 10-13)")
            }
            // Android 9 and below
            else -> {
                startForeground(1001, notification)
                Log.d(TAG, "✅ Started plain (Android 9-)")
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        Log.d(TAG, "🛑 ScreenShareService destroyed")
        super.onDestroy()
    }
}
