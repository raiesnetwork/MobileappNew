package com.ixes.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onCreate() {
        super.onCreate()
        android.util.Log.d("IXES_FCM", "🟢 MyFirebaseMessagingService.onCreate() called")
        createNotificationChannels()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        val type = data["type"] ?: ""

        android.util.Log.d("IXES_FCM", "═══════════════════════════════════════════════════════")
        android.util.Log.d("IXES_FCM", "🟢 onMessageReceived() CALLED (NATIVE KOTLIN)")
        android.util.Log.d("IXES_FCM", "📲 type=$type")
        android.util.Log.d("IXES_FCM", "📦 Full data: $data")
        android.util.Log.d("IXES_FCM", "═══════════════════════════════════════════════════════")

        // ✅ FIX: Ignore empty/dummy notifications
        if (data.isEmpty()) {
            android.util.Log.d("IXES_FCM", "⚠️ Empty payload received — ignoring")
            return
        }

        if (type.isEmpty()) {
            android.util.Log.d("IXES_FCM", "⚠️ No 'type' field — ignoring")
            return
        }

        // Ensure channels exist
        createNotificationChannels()

        // ── CALL notifications ──────────────────────────────────────
        if (type == "voice_call" || type == "video_call") {
            val roomName   = data["roomName"]   ?: ""
            val callerId   = data["callerId"]   ?: ""
            val callerName = data["callerName"] ?: "Incoming Call"

            if (roomName.isEmpty() || callerId.isEmpty()) {
                android.util.Log.d("IXES_FCM", "⚠️ Missing roomName or callerId — skipping")
                return
            }

            android.util.Log.d("IXES_FCM", "📞 Intercepting call: $type | room=$roomName | caller=$callerName")

            try {
                val notifManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                notifManager.cancelAll()
                android.util.Log.d("IXES_FCM", "✅ Cancelled all notifications to prevent double ringing")
            } catch (e: Exception) {
                android.util.Log.e("IXES_FCM", "Could not cancel notifications: $e")
            }

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

        // ── CHAT notifications ──────────────────────────────────────
        if (type == "chat") {
            android.util.Log.d("IXES_FCM", "🟡 Processing CHAT notification")

            val senderName = getSenderName(data)
            val body       = data["body"] ?: data["message"] ?: "You have a new message"
            val senderId   = data["senderId"] ?: ""
            val conversationId = data["conversationId"] ?: ""
            val groupId    = data["groupId"] ?: ""
            val title = data["title"] ?: ""
            val isGroupChat = title.contains("group", ignoreCase = true) ||
                    title.contains("Group", ignoreCase = true)

            android.util.Log.d("IXES_FCM", "🔍 Chat Check | isGroupChat=$isGroupChat | conversationId=$conversationId | title='$title'")

            if (isGroupChat && conversationId.isNotEmpty()) {
                val groupName = extractGroupNameFromTitle(title)
                android.util.Log.d("IXES_FCM", "💬 GROUP CHAT detected | conversationId=$conversationId | groupName=$groupName")
                showChatNotification(
                    title          = title,
                    body           = body,
                    type           = "GroupChat",
                    senderId       = "",
                    senderName     = senderName,
                    conversationId = "",
                    groupId        = conversationId,
                    groupName      = groupName,
                )
            } else {
                android.util.Log.d("IXES_FCM", "💬 PERSONAL CHAT detected | sender=$senderName")
                showChatNotification(
                    title          = senderName,
                    body           = body,
                    type           = type,
                    senderId       = senderId,
                    senderName     = senderName,
                    conversationId = conversationId,
                    groupId        = "",
                )
            }
            return
        }

        // ── GROUP CHAT notifications ────────────────────────────────
        if (type == "GroupChat") {
            android.util.Log.d("IXES_FCM", "🟡 Processing GROUP CHAT notification")

            val groupName  = data["groupName"]     ?: "Group"
            val senderName = getSenderName(data)
            val body       = data["body"] ?: data["message"] ?: "New group message"
            val groupId    = data["groupId"]       ?: ""

            android.util.Log.d("IXES_FCM", "💬 GroupChat | groupId=$groupId | groupName=$groupName | senderName=$senderName")

            val title = groupName
            val displayBody = if (senderName.isNotEmpty()) "$senderName: $body" else body

            showChatNotification(
                title          = title,
                body           = displayBody,
                type           = type,
                senderId       = "",
                senderName     = senderName,
                conversationId = "",
                groupId        = groupId,
                groupName      = groupName,
            )
            return
        }

        android.util.Log.d("IXES_FCM", "ℹ️ Unhandled type=$type — skipping")
    }

    private fun getSenderName(data: Map<String, String>): String {
        val senderName = data["senderName"]
            ?: data["sender"]
            ?: data["from"]
            ?: data["userName"]
            ?: data["name"]
            ?: data["title"]
            ?: "Chat"

        android.util.Log.d("IXES_FCM", "👤 getSenderName='$senderName'")
        return senderName
    }

    private fun extractGroupNameFromTitle(title: String): String {
        val regex = Regex("""in the (.+?) group""")
        val match = regex.find(title)

        if (match != null) {
            val groupName = match.groupValues[1]
            android.util.Log.d("IXES_FCM", "✅ Extracted groupName='$groupName'")
            return groupName
        }

        return "Group"
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            android.util.Log.d("IXES_FCM", "🔧 Creating notification channels...")

            // ✅ DELETE OLD CHANNEL
            try {
                notificationManager.deleteNotificationChannel("chat_notifications")
                android.util.Log.d("IXES_FCM", "✅ Deleted old chat channel")
            } catch (e: Exception) {
                android.util.Log.d("IXES_FCM", "⚠️ Could not delete old chat channel: $e")
            }

            // ── CHAT CHANNEL WITH SOUND ────────────────────────────────
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            android.util.Log.d("IXES_FCM", "🔊 Sound URI: $soundUri")

            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val chatChannel = NotificationChannel(
                "chat_notifications",
                "Chat Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Chat notifications with sound"
                enableLights(true)
                lightColor = android.graphics.Color.GREEN
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 250, 500)
                setShowBadge(true)

                // ✅ SET SOUND AT CHANNEL LEVEL
                setSound(soundUri, audioAttributes)

                android.util.Log.d("IXES_FCM", "🔧 Chat channel config: sound=$soundUri, importance=HIGH")
            }

            // ── CALL CHANNEL ───────────────────────────────────────────
            val callChannel = NotificationChannel(
                "call_notifications",
                "Incoming Calls",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Call notifications without sound (CallKit handles)"
                enableLights(true)
                enableVibration(true)
                setSound(null, null)
            }

            // ── GENERAL CHANNEL ────────────────────────────────────────
            val generalChannel = NotificationChannel(
                "general_notifications",
                "General Notifications",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "General app notifications"
            }

            try {
                notificationManager.createNotificationChannel(chatChannel)
                android.util.Log.d("IXES_FCM", "✅ Chat channel created (IMPORTANCE_HIGH + SOUND)")
            } catch (e: Exception) {
                android.util.Log.e("IXES_FCM", "❌ Failed to create chat channel: $e")
            }

            try {
                notificationManager.createNotificationChannel(callChannel)
                android.util.Log.d("IXES_FCM", "✅ Call channel created")
            } catch (e: Exception) {
                android.util.Log.e("IXES_FCM", "❌ Failed to create call channel: $e")
            }

            try {
                notificationManager.createNotificationChannel(generalChannel)
                android.util.Log.d("IXES_FCM", "✅ General channel created")
            } catch (e: Exception) {
                android.util.Log.e("IXES_FCM", "❌ Failed to create general channel: $e")
            }
        } else {
            android.util.Log.d("IXES_FCM", "⚠️ Android version < 8.0, skipping channel creation")
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
        groupName:      String = "Group",
    ) {
        android.util.Log.d("IXES_FCM", "═══════════════════════════════════════════════════════")
        android.util.Log.d("IXES_FCM", "📢 showChatNotification() BUILDING NOTIFICATION")
        android.util.Log.d("IXES_FCM", "   title='$title' | body='$body' | type=$type")
        android.util.Log.d("IXES_FCM", "   senderName='$senderName' | groupName='$groupName'")
        android.util.Log.d("IXES_FCM", "═══════════════════════════════════════════════════════")

        val channelId    = "chat_notifications"
        val notifManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        val finalTitle = if (title.isNotEmpty() && title != "Chat") title else "New Message"
        val finalBody = if (body.isNotEmpty()) body else "You have a new message"

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
            putExtra("groupName",      groupName)
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

        // ✅ DO NOT SET SOUND HERE — Channel controls it
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(finalTitle)
            .setContentText(finalBody)
            .setStyle(NotificationCompat.BigTextStyle().bigText(finalBody))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 500, 250, 500))
            .setColor(android.graphics.Color.GREEN)
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
            android.util.Log.d("IXES_FCM", "✅ NOTIFICATION DISPLAYED")
            android.util.Log.d("IXES_FCM", "   ID: $notifId")
            android.util.Log.d("IXES_FCM", "   Title: $finalTitle")
            android.util.Log.d("IXES_FCM", "   Body: $finalBody")
            android.util.Log.d("IXES_FCM", "   Channel: $channelId")
            android.util.Log.d("IXES_FCM", "═══════════════════════════════════════════════════════")
        } catch (e: Exception) {
            android.util.Log.e("IXES_FCM", "❌ FAILED TO SHOW NOTIFICATION: ${e.message}")
            android.util.Log.e("IXES_FCM", android.util.Log.getStackTraceString(e))
        }
    }
}