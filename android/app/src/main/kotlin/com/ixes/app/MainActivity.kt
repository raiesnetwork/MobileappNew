package com.ixes.app

import android.content.Intent
import android.os.Build
import android.app.NotificationChannel
import android.app.NotificationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SCREEN_CHANNEL = "com.ixes.app/screen_share"
    private val CALL_CHANNEL   = "com.ixes.app/calls"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Existing screen share channel ──────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScreenShareService" -> {
                        val serviceIntent = Intent(this, ScreenShareService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(null)
                    }
                    "stopScreenShareService" -> {
                        stopService(Intent(this, ScreenShareService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── New call channel ───────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                result.notImplemented()
            }

        // ── Create notification channel for calls ──────────────────────
        createCallNotificationChannel()
    }

    // Called when app is already running and a new intent arrives
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleCallIntent(intent)
    }

    // Called when app launches fresh from a notification tap
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallIntent(intent)
    }

    private fun handleCallIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("isCallIntent", false) != true) return

        val type       = intent.getStringExtra("type")       ?: return
        val roomName   = intent.getStringExtra("roomName")   ?: return
        val callerId   = intent.getStringExtra("callerId")   ?: return
        val callerName = intent.getStringExtra("callerName") ?: "Incoming Call"

        android.util.Log.d("IXES_CALL", "📲 handleCallIntent: type=$type room=$roomName")

        // Send to Flutter — engine may not be ready yet, so post with delay
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CALL_CHANNEL).invokeMethod(
                    "incomingCall",
                    mapOf(
                        "type"       to type,
                        "roomName"   to roomName,
                        "callerId"   to callerId,
                        "callerName" to callerName,
                    )
                )
                android.util.Log.d("IXES_CALL", "✅ Sent incomingCall to Flutter")
            }
        }, 2000) // 2s delay — wait for Flutter engine to be ready
    }

    private fun createCallNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "call_channel",
                "Incoming Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Incoming voice and video calls"
                enableVibration(true)
                setSound(
                    android.provider.Settings.System.DEFAULT_RINGTONE_URI,
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}