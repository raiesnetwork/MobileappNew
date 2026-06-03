package com.ixes.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SCREEN_CHANNEL = "com.ixes.app/screen_share"
    private val CALL_CHANNEL   = "com.ixes.app/calls"
    private val CHAT_CHANNEL   = "com.ixes.app/chat"
    private val FGS_PERMISSION = "android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"
    private val PERMISSION_REQUEST_CODE = 1001

    private var pendingScreenShareResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        createNotificationChannels()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallIntent(intent)
        handleChatIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleCallIntent(intent)
        handleChatIntent(intent)
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
        if (intent?.getBooleanExtra("isChatIntent", false) != true) return

        val type           = intent.getStringExtra("type")           ?: return
        val senderId       = intent.getStringExtra("senderId")       ?: ""
        val senderName     = intent.getStringExtra("senderName")     ?: ""
        val conversationId = intent.getStringExtra("conversationId") ?: ""
        val groupId        = intent.getStringExtra("groupId")        ?: ""

        Log.d("MainActivity", "💬 handleChatIntent | type=$type | senderId=$senderId | senderName=$senderName | groupId=$groupId")

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
                    )
                )
                Log.d("MainActivity", "✅ chatTapped sent to Flutter | senderName=$senderName")
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

            // ✅ CRITICAL: Wait 1 second for service to fully initialize
            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            handler.postDelayed({
                Log.d("MainActivity", "✅ Service fully initialized, returning success to Flutter")
                result.success(null)
            }, 1000)

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
}