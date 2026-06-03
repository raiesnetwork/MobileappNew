package com.ixes.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        val type = data["type"] ?: ""

        android.util.Log.d("IXES_FCM", "📲 onMessageReceived: type=$type")
        android.util.Log.d("IXES_FCM", "📦 Full data: $data")

        // Ensure channels exist
        createNotificationChannels()

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

            // ✅ CRITICAL FIX: Cancel ALL notifications to prevent duplicate ringing
            try {
                val notifManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                notifManager.cancelAll()
                android.util.Log.d("IXES_FCM", "✅ Cancelled all notifications to prevent double ringing")
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
            // ✅ CRITICAL FIX: Try multiple field names for sender
            val senderName = getSenderName(data)  // Use new helper function
            val body       = data["body"] ?: data["message"] ?: "You have a new message"
            val senderId   = data["senderId"] ?: ""
            val conversationId = data["conversationId"] ?: ""

            android.util.Log.d("IXES_FCM", "💬 Chat notification | senderName='$senderName' | body='$body'")
            android.util.Log.d("IXES_FCM", "   senderId=$senderId | conversationId=$conversationId")

            showChatNotification(
                title          = senderName,      // Use actual sender name, not "New Message"
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
            val groupName  = data["groupName"]     ?: "Group"
            val senderName = getSenderName(data)   // Use helper here too
            val body       = data["body"] ?: data["message"] ?: "New group message"
            val groupId    = data["groupId"]       ?: ""

            // Show as "GroupName" in title, "SenderName: message" in body
            val title = groupName
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

    // ── NEW HELPER: Get sender name from multiple possible field names ─────
    private fun getSenderName(data: Map<String, String>): String {
        // Try these field names in order (backend might use different names)
        val senderName = data["senderName"]      // First try
            ?: data["sender"]                     // Alternative 1
            ?: data["from"]                       // Alternative 2
            ?: data["userName"]                   // Alternative 3
            ?: data["name"]                       // Alternative 4
            ?: data["title"]                      // Alternative 5 (fallback)
            ?: "Chat"                             // Default fallback

        android.util.Log.d("IXES_FCM", "🔍 getSenderName result: '$senderName' (from ${data.keys})")
        return senderName
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            // ── CHAT NOTIFICATIONS CHANNEL ────────────────────────────────
            val chatChannelId = "chat_notifications"
            val chatChannelName = "Chat Messages"
            val chatChannelDescription = "Notifications for new chat messages"

            val chatChannel = NotificationChannel(chatChannelId, chatChannelName, NotificationManager.IMPORTANCE_HIGH).apply {
                description = chatChannelDescription
                enableLights(true)
                enableVibration(true)
                setSound(null, null) // No sound for chat (optional)
            }

            try {
                notificationManager.createNotificationChannel(chatChannel)
                android.util.Log.d("IXES_FCM", "✅ Chat notification channel created: $chatChannelId")
            } catch (e: Exception) {
                android.util.Log.e("IXES_FCM", "❌ Failed to create chat channel: $e")
            }

            // ── CALL NOTIFICATIONS CHANNEL ────────────────────────────────
            val callChannelId = "call_notifications"
            val callChannelName = "Incoming Calls"
            val callChannelDescription = "Notifications for incoming calls"

            val callChannel = NotificationChannel(callChannelId, callChannelName, NotificationManager.IMPORTANCE_MAX).apply {
                description = callChannelDescription
                enableLights(true)
                enableVibration(true)
                // NO SOUND - CallKit will handle the ringtone
                setSound(null, null)
            }

            try {
                notificationManager.createNotificationChannel(callChannel)
                android.util.Log.d("IXES_FCM", "✅ Call notification channel created: $callChannelId")
            } catch (e: Exception) {
                android.util.Log.e("IXES_FCM", "❌ Failed to create call channel: $e")
            }

            // ── OTHER NOTIFICATIONS CHANNEL ────────────────────────────────
            val generalChannelId = "general_notifications"
            val generalChannelName = "General Notifications"
            val generalChannelDescription = "General app notifications"

            val generalChannel = NotificationChannel(generalChannelId, generalChannelName, NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = generalChannelDescription
            }

            try {
                notificationManager.createNotificationChannel(generalChannel)
                android.util.Log.d("IXES_FCM", "✅ General notification channel created: $generalChannelId")
            } catch (e: Exception) {
                android.util.Log.e("IXES_FCM", "❌ Failed to create general channel: $e")
            }
        }
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

        // ── Ensure data is not empty ──────────────────────────────────────
        val finalTitle = if (title.isNotEmpty() && title != "Chat") title else "New Message"
        val finalBody = if (body.isNotEmpty()) body else "You have a new message"

        android.util.Log.d("IXES_FCM", "📨 Building notification | finalTitle='$finalTitle' | finalBody='$finalBody'")

        // ── Tap intent — opens app, Flutter handles deep navigation ─────────
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

            // CRITICAL: Add these extras so data survives app kill
            putExtra("notificationTitle", finalTitle)
            putExtra("notificationBody", finalBody)
        }

        val requestCode = if (conversationId.isNotEmpty()) {
            conversationId.hashCode()
        } else if (groupId.isNotEmpty()) {
            groupId.hashCode()
        } else {
            System.currentTimeMillis().toInt()
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(finalTitle)    // ✅ Actual sender name
            .setContentText(finalBody)      // ✅ Actual message text
            .setStyle(NotificationCompat.BigTextStyle().bigText(finalBody))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

            .setSound(null)
            .setVibrate(null)
            .build()

        val notifId = if (conversationId.isNotEmpty()) {
            conversationId.hashCode()
        } else if (groupId.isNotEmpty()) {
            groupId.hashCode()
        } else {
            System.currentTimeMillis().toInt()
        }

        try {
            notifManager.notify(notifId, notification)
            android.util.Log.d("IXES_FCM", "✅ Chat notification shown | ID=$notifId | title='$finalTitle' | senderName='$senderName'")
        } catch (e: Exception) {
            android.util.Log.e("IXES_FCM", "❌ Failed to show notification: $e")
        }
    }
}