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

        // ✅ Use MEDIA_PROJECTION type on Android 10+ (required so flutter_webrtc's
        // MediaProjection can start). We do NOT pass a token here — we let flutter_webrtc
        // handle the permission grant entirely. The OS only requires that a FGS with
        // mediaProjection type is RUNNING before MediaProjection.start() is called.
        // On Android 14, not passing the token here is fine because flutter_webrtc
        // already gets the token from its own permission dialog and passes it to
        // MediaProjectionManager internally.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                1001,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
            Log.d(TAG, "Started with MEDIA_PROJECTION type")
        } else {
            startForeground(1001, notification)
            Log.d(TAG, "Started plain (Android 9-)")
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}