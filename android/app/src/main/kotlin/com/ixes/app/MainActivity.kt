package com.ixes.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SCREEN_CHANNEL = "com.ixes.app/screen_share"
    private val CALL_CHANNEL   = "com.ixes.app/calls"
    private val CHAT_CHANNEL   = "com.ixes.app/chat"
    private val CHAT_NOTIF_CHANNEL = "com.ixes.app/chat_notification"  // ← CHAT NOTIFICATIONS
    private val NOTIF_MANAGER_CHANNEL = "com.ixes.app/notification_manager"  // ✅ ADD THIS - NOTIFICATION REMOVAL
    private val APP_LAUNCHER_CHANNEL = "com.ixes.app/app_launcher"     // ← APP LAUNCHER
    private val FGS_PERMISSION = "android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"
    private val PERMISSION_REQUEST_CODE = 1001

    private var pendingScreenShareResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Existing channels ──────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScreenShareService" -> {
                        handleStartScreenShare(result)
                    }
                    "stopScreenShareService" -> {
                        try {
                            stopService(Intent(this, ScreenShareService::class.java))
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "❌ Failed to stop service: ${e.message}")
                            result.error("SERVICE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setMethodCallHandler { _, result -> result.notImplemented() }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHAT_CHANNEL)
            .setMethodCallHandler { _, result -> result.notImplemented() }

        // ────────────────────────────────────────────────────────────────────────────
        // ✅ NOTIFICATION MANAGER CHANNEL: Remove notifications by ID
        // ────────────────────────────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_MANAGER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "removeNotification" -> {
                        try {
                            val notificationId = call.argument<Int>("notificationId") ?: 0
                            val notificationManager = getSystemService(NotificationManager::class.java)
                            notificationManager.cancel(notificationId)

                            Log.d("MainActivity", "✅ [CANCEL] Removed notification from tray | id=$notificationId")
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "❌ [CANCEL] Error: ${e.message}")
                            result.error("NOTIF_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ────────────────────────────────────────────────────────────────────────────
        // ✅ APP LAUNCHER CHANNEL: Launch app from DECLINE action
        // ────────────────────────────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_LAUNCHER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchApp" -> {
                        try {
                            launchAppInForeground()
                            result.success(null)
                            Log.d("MainActivity", "✅ [APP_LAUNCHER] launchApp() succeeded")
                        } catch (e: Exception) {
                            Log.e("MainActivity", "❌ [APP_LAUNCHER] Error: ${e.message}")
                            result.error("LAUNCH_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ────────────────────────────────────────────────────────────────────────────
        // ✅ CHAT NOTIFICATION CHANNEL: Handle chat notifications from Flutter background handler
        // ────────────────────────────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHAT_NOTIF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showNotification" -> {
                        try {
                            val title = call.argument<String>("title") ?: "New Message"
                            val body = call.argument<String>("body") ?: "You have a new message"
                            val senderName = call.argument<String>("senderName") ?: ""
                            val senderId = call.argument<String>("senderId") ?: ""
                            val conversationId = call.argument<String>("conversationId") ?: ""
                            val groupId = call.argument<String>("groupId") ?: ""
                            val groupName = call.argument<String>("groupName") ?: "Group"

                            Log.d("MainActivity", "📲 [CHANNEL] showNotification called | title=$title | body=$body")

                            showChatNotificationFromChannel(
                                title = title,
                                body = body,
                                senderName = senderName,
                                senderId = senderId,
                                conversationId = conversationId,
                                groupId = groupId,
                                groupName = groupName,
                            )

                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "❌ showNotification error: ${e.message}")
                            result.error("NOTIFICATION_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        createNotificationChannels()
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallIntent(intent)
        handleChatIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleCallIntent(intent)
        handleChatIntent(intent)
    }

    // ────────────────────────────────────────────────────────────────────────────
    // ✅ NEW: Launch app from DECLINE action
    // ────────────────────────────────────────────────────────────────────────────

    private fun launchAppInForeground() {
        Log.d("MainActivity", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d("MainActivity", "🚀 [DECLINE] Launching app in foreground...")
        Log.d("MainActivity", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        try {
            startActivity(intent)
            Log.d("MainActivity", "✅ [DECLINE] App launched successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ [DECLINE] Failed to launch app: ${e.message}")
        }
    }

    // ── Call handler ───────────────────────────────────────────────────────
    private fun handleCallIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("isCallIntent", false) != true) return

        val type       = intent.getStringExtra("type")       ?: return
        val roomName   = intent.getStringExtra("roomName")   ?: return
        val callerId   = intent.getStringExtra("callerId")   ?: return
        val callerName = intent.getStringExtra("callerName") ?: "Incoming Call"

        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CALL_CHANNEL).invokeMethod(
                    "incomingCall",
                    mapOf(
                        "type"       to type,
                        "roomName"   to roomName,
                        "callerId"   to callerId,
                        "callerName" to callerName
                    )
                )
            }
        }, 2000)
    }

    // ── Chat handler ───────────────────────────────────────────────────────
    private fun handleChatIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("isChatIntent", false) != true) {
            Log.d("MainActivity", "⚠️ handleChatIntent: isChatIntent is false or missing")
            return
        }

        val type           = intent.getStringExtra("type")           ?: return
        val senderId       = intent.getStringExtra("senderId")       ?: ""
        val senderName     = intent.getStringExtra("senderName")     ?: ""
        val conversationId = intent.getStringExtra("conversationId") ?: ""
        val groupId        = intent.getStringExtra("groupId")        ?: ""
        val groupName      = intent.getStringExtra("groupName")      ?: "Group"

        Log.d("MainActivity", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Log.d("MainActivity", "💬 handleChatIntent RECEIVED")
        Log.d("MainActivity", "  type=$type")
        Log.d("MainActivity", "  senderId='$senderId' (length=${senderId.length})")
        Log.d("MainActivity", "  senderName='$senderName'")
        Log.d("MainActivity", "  conversationId='$conversationId'")
        Log.d("MainActivity", "  groupId='$groupId' (length=${groupId.length})")
        Log.d("MainActivity", "  groupName='$groupName'")
        Log.d("MainActivity", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHAT_CHANNEL).invokeMethod(
                    "chatTapped",
                    mapOf(
                        "type"           to type,
                        "senderId"       to senderId,
                        "senderName"     to senderName,
                        "conversationId" to conversationId,
                        "groupId"        to groupId,
                        "groupName"      to groupName,
                    )
                )
                Log.d("MainActivity", "✅ chatTapped sent to Flutter | type=$type | groupId=$groupId")
            }
        }, 1500)
    }

    // ── Screen share handler ───────────────────────────────────────────────
    private fun handleStartScreenShare(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val granted = ContextCompat.checkSelfPermission(this, FGS_PERMISSION) ==
                    PackageManager.PERMISSION_GRANTED
            Log.d("MainActivity", "🔍 FGS_MEDIA_PROJECTION permission granted: $granted")

            if (!granted) {
                pendingScreenShareResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(FGS_PERMISSION),
                    PERMISSION_REQUEST_CODE
                )
                return
            }
        }
        startScreenShareServiceAndNotify(result)
    }

    private fun startScreenShareServiceAndNotify(result: MethodChannel.Result) {
        try {
            val serviceIntent = Intent(this, ScreenShareService::class.java)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }

            Log.d("MainActivity", "✅ startForegroundService called")

            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            handler.postDelayed({
                Log.d("MainActivity", "✅ Service fully initialized (2000ms delay), returning success to Flutter")
                result.success(null)
            }, 2000)

        } catch (e: SecurityException) {
            Log.e("MainActivity", "❌ SecurityException: ${e.message}")
            result.error("PERMISSION_DENIED", e.message, null)
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Exception: ${e.message}")
            result.error("SERVICE_ERROR", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == PERMISSION_REQUEST_CODE) {
            val result = pendingScreenShareResult ?: return
            pendingScreenShareResult = null

            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d("MainActivity", "✅ FGS permission granted by user")
                startScreenShareServiceAndNotify(result)
            } else {
                Log.e("MainActivity", "❌ FGS permission denied by user")
                result.error("PERMISSION_DENIED", "Foreground service permission denied", null)
            }
        }
    }

    // ── Notification channels ──────────────────────────────────────────────
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notifManager = getSystemService(NotificationManager::class.java)

            // Chat channel
            val chatChannel = NotificationChannel(
                "chat_notifications",
                "Chat Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Chat message notifications"
                enableLights(true)
                enableVibration(true)
                setSound(null, null)
            }
            notifManager.createNotificationChannel(chatChannel)

            // Call channel
            val callChannel = NotificationChannel(
                "call_notifications",
                "Incoming Calls",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Incoming voice and video calls"
                enableVibration(true)
            }
            notifManager.createNotificationChannel(callChannel)
        }
    }

    // ────────────────────────────────────────────────────────────────────────────
    // ✅ Show chat notification from Flutter MethodChannel
    // ────────────────────────────────────────────────────────────────────────────

    private fun showChatNotificationFromChannel(
        title: String,
        body: String,
        senderName: String,
        senderId: String,
        conversationId: String,
        groupId: String,
        groupName: String,
    ) {
        val channelId = "chat_notifications"
        val notifManager = getSystemService(NotificationManager::class.java)

        val finalTitle = if (title.isNotEmpty() && title != "Chat") title else "New Message"
        val finalBody = if (body.isNotEmpty()) body else "You have a new message"

        Log.d("MainActivity", "═══════════════════════════════════════════════════════")
        Log.d("MainActivity", "📲 [FLUTTER→NATIVE] showChatNotificationFromChannel()")
        Log.d("MainActivity", "   title='$finalTitle' | body='$finalBody'")
        Log.d("MainActivity", "   senderName='$senderName' | groupName='$groupName'")
        Log.d("MainActivity", "═══════════════════════════════════════════════════════")

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("isChatIntent",   true)
            putExtra("type",           if (groupId.isNotEmpty()) "GroupChat" else "chat")
            putExtra("senderId",       senderId)
            putExtra("senderName",     senderName)
            putExtra("conversationId", conversationId)
            putExtra("groupId",        groupId)
            putExtra("groupName",      groupName)
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
            .setContentTitle(finalTitle)
            .setContentText(finalBody)
            .setStyle(NotificationCompat.BigTextStyle().bigText(finalBody))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 500, 250, 500))
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
            Log.d("MainActivity", "✅ NOTIFICATION DISPLAYED FROM FLUTTER")
            Log.d("MainActivity", "   ID: $notifId | Title: $finalTitle | Body: $finalBody")
            Log.d("MainActivity", "═══════════════════════════════════════════════════════")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Failed to show notification: ${e.message}")
        }
    }
}