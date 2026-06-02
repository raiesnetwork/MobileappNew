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

        // ── CHAT notifications ─────────────────────────────────────────────
        if (type == "chat") {
            // Backend sends: data[senderName], data[title], data[body]
            // ✅ Use senderName as notification title (the person's name)
            // ✅ Use body as notification body (the message text)
            val title          = data["senderName"]     ?: data["title"] ?: "New Message"
            val body           = data["body"]           ?: "You have a new message"
            val senderId       = data["senderId"]       ?: ""
            val senderName     = data["senderName"]     ?: ""
            val conversationId = data["conversationId"] ?: ""

            android.util.Log.d("IXES_FCM", "💬 Chat notification | title=$title | body=$body")
            android.util.Log.d("IXES_FCM", "   senderId=$senderId | senderName=$senderName | conversationId=$conversationId")

            showChatNotification(
                title          = title,
                body           = body,
                type           = type,
                senderId       = senderId,
                senderName     = senderName,
                conversationId = conversationId,
                groupId        = "",
            )
            return
        }

        // ── GROUP CHAT notifications ───────────────────────────────────────
        if (type == "GroupChat") {
            // Backend sends: data[groupName], data[senderName], data[body]
            // ✅ Show group name as title, message as body
            val groupName  = data["groupName"]     ?: "Group"
            val senderName = data["senderName"]    ?: ""
            val body       = data["body"]          ?: data["message"] ?: "New group message"
            val groupId    = data["groupId"]       ?: ""

            // Show as "GroupName: SenderName" or just groupName if no sender
            val title = if (senderName.isNotEmpty()) "$groupName" else groupName
            // Show as "SenderName: message" in body
            val displayBody = if (senderName.isNotEmpty()) "$senderName: $body" else body

            android.util.Log.d("IXES_FCM", "💬 GroupChat notification | title=$title | body=$displayBody")
            android.util.Log.d("IXES_FCM", "   groupId=$groupId | groupName=$groupName | senderName=$senderName")

            showChatNotification(
                title          = title,
                body           = displayBody,
                type           = type,
                senderId       = "",
                senderName     = senderName,
                conversationId = "",
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
        val channelId    = "chat_notifications"
        val notifManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        // ── Tap intent — opens app, Flutter handles deep navigation ─────────
        // We pass all chat data so MainActivity → Flutter can navigate
        // to the right screen when user taps the notification
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("isChatIntent",   true)
            putExtra("type",           type)
            putExtra("senderId",       senderId)
            putExtra("senderName",     senderName)
            putExtra("conversationId", conversationId)
            putExtra("groupId",        groupId)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            // Use conversationId/groupId as request code so
            // same conversation updates the same notification
            if (conversationId.isNotEmpty()) conversationId.hashCode()
            else groupId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)   // ✅ senderName or groupName
            .setContentText(body)     // ✅ actual message text from data[body]
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setSound(null)
            .setVibrate(null)
            .build()

        // Use conversationId/groupId as notification ID so messages from
        // the same conversation stack/update instead of creating new ones
        val notifId = if (conversationId.isNotEmpty()) conversationId.hashCode()
        else if (groupId.isNotEmpty())   groupId.hashCode()
        else System.currentTimeMillis().toInt()

        notifManager.notify(notifId, notification)

        android.util.Log.d("IXES_FCM", "✅ Chat notification shown | title=$title")
    }
}