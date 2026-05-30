package com.ixes.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        val type = data["type"] ?: ""

        android.util.Log.d("IXES_FCM", "📲 onMessageReceived: type=$type")

        // ── CALL notifications: intercept and show CallKit UI ──────────────
        if (type == "voice_call" || type == "video_call") {
            val roomName   = data["roomName"]   ?: ""
            val callerId   = data["callerId"]   ?: ""
            val callerName = data["callerName"] ?: "Incoming Call"

            if (roomName.isEmpty() || callerId.isEmpty()) {
                android.util.Log.d("IXES_FCM", "⚠️ Missing roomName or callerId — skipping")
                return
            }

            android.util.Log.d("IXES_FCM", "📞 Intercepting call: $type | room=$roomName | caller=$callerName")

            // Cancel any auto-shown system notification
            try {
                val notifManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                notifManager.cancelAll()
            } catch (e: Exception) {
                android.util.Log.e("IXES_FCM", "Could not cancel notifications: $e")
            }

            // Launch MainActivity with call data for Flutter/CallKit to handle
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("isCallIntent", true)
                putExtra("type",       type)
                putExtra("roomName",   roomName)
                putExtra("callerId",   callerId)
                putExtra("callerName", callerName)
            }

            android.util.Log.d("IXES_FCM", "🚀 Starting MainActivity with call intent")
            startActivity(intent)
            return
        }

        // ── CHAT notifications: show silent notification with sender name ──
        if (type == "chat" || type == "GroupChat") {
            val title   = data["senderName"]  ?: data["groupName"] ?: "New Message"
            val body    = data["message"]     ?: "You have a new message"
            val senderId       = data["senderId"]       ?: ""
            val conversationId = data["conversationId"] ?: ""
            val groupId        = data["groupId"]        ?: ""

            android.util.Log.d("IXES_FCM", "💬 Chat notification | title=$title | body=$body")

            showChatNotification(
                title          = title,
                body           = body,
                type           = type,
                senderId       = senderId,
                senderName     = title,
                conversationId = conversationId,
                groupId        = groupId,
            )
            return
        }

        // ── All other types: let FCM handle automatically ──────────────────
        android.util.Log.d("IXES_FCM", "ℹ️ Unhandled type=$type — letting FCM handle")
    }

    private fun showChatNotification(
        title:          String,
        body:           String,
        type:           String,
        senderId:       String,
        senderName:     String,
        conversationId: String,
        groupId:        String,
    ) {
        val channelId = "chat_notifications"
        val notifManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        // Create silent notification channel (no sound, no vibration)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Chat Messages",
                // ✅ IMPORTANCE_DEFAULT shows notification but plays NO ringtone
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description       = "Chat message notifications"
                setSound(null, null)   // ✅ No sound
                enableVibration(false) // ✅ No vibration
            }
            notifManager.createNotificationChannel(channel)
        }

        // Tap intent — opens app and Flutter handles navigation
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("type",           type)
            putExtra("senderId",       senderId)
            putExtra("senderName",     senderName)
            putExtra("conversationId", conversationId)
            putExtra("groupId",        groupId)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setSound(null)        // ✅ No sound
            .setVibrate(null)      // ✅ No vibration
            .build()

        val notifId = System.currentTimeMillis().toInt()
        notifManager.notify(notifId, notification)

        android.util.Log.d("IXES_FCM", "✅ Chat notification shown | title=$title")
    }
}