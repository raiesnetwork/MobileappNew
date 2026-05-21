package com.ixes.app

import android.app.NotificationManager
import android.content.Intent
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        val type = data["type"] ?: ""

        android.util.Log.d("IXES_FCM", "📲 onMessageReceived: type=$type")

        // Only intercept call notifications
        if (type != "voice_call" && type != "video_call") return

        val roomName   = data["roomName"]   ?: ""
        val callerId   = data["callerId"]   ?: ""
        val callerName = data["callerName"] ?: "Incoming Call"

        if (roomName.isEmpty() || callerId.isEmpty()) {
            android.util.Log.d("IXES_FCM", "⚠️ Missing roomName or callerId — skipping")
            return
        }

        android.util.Log.d("IXES_FCM", "📞 Intercepting call: $type | room=$roomName | caller=$callerName")

        // Cancel the auto-shown system notification from the notification block
        try {
            val notifManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notifManager.cancelAll()
        } catch (e: Exception) {
            android.util.Log.e("IXES_FCM", "Could not cancel notifications: $e")
        }

        // Launch MainActivity with call data
        // This wakes the app and lets Flutter show CallKit UI
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("isCallIntent", true)
            putExtra("type",       type)
            putExtra("roomName",   roomName)
            putExtra("callerId",   callerId)
            putExtra("callerName", callerName)
        }

        android.util.Log.d("IXES_FCM", "🚀 Starting MainActivity with call intent")
        startActivity(intent)
    }
}