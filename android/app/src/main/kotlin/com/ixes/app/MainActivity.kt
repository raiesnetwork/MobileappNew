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
    private val FGS_PERMISSION = "android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"
    private val PERMISSION_REQUEST_CODE = 1001

    // Hold result while waiting for permission grant
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

        createCallNotificationChannel()
    }

    private fun handleStartScreenShare(result: MethodChannel.Result) {
        // On Android 14+ (API 34+), check if permission is granted
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val granted = ContextCompat.checkSelfPermission(this, FGS_PERMISSION) ==
                    PackageManager.PERMISSION_GRANTED
            Log.d("MainActivity", "🔍 FGS_MEDIA_PROJECTION permission granted: $granted")

            if (!granted) {
                // Store result, request permission, then start service in callback
                pendingScreenShareResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(FGS_PERMISSION),
                    PERMISSION_REQUEST_CODE
                )
                return
            }
        }
        // Permission already granted (or Android < 14) — start directly
        startScreenShareServiceAndNotify(result)
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

    private fun startScreenShareServiceAndNotify(result: MethodChannel.Result) {
        try {
            val serviceIntent = Intent(this, ScreenShareService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            Log.d("MainActivity", "✅ startForegroundService called")

            // Poll until service is actually running — max 3 seconds
            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            var elapsed = 0
            val interval = 150
            val maxWait = 3000

            val checker = object : Runnable {
                override fun run() {
                    elapsed += interval
                    val running = isScreenShareServiceRunning()
                    Log.d("MainActivity", "⏳ FGS check at ${elapsed}ms — running=$running")

                    when {
                        running -> {
                            Log.d("MainActivity", "✅ FGS confirmed running at ${elapsed}ms")
                            result.success(null)
                        }
                        elapsed >= maxWait -> {
                            Log.e("MainActivity", "❌ FGS never confirmed after ${maxWait}ms")
                            // Still try — better than refusing
                            result.success(null)
                        }
                        else -> handler.postDelayed(this, interval.toLong())
                    }
                }
            }
            handler.postDelayed(checker, interval.toLong())

        } catch (e: SecurityException) {
            Log.e("MainActivity", "❌ SecurityException: ${e.message}")
            result.error("PERMISSION_DENIED", e.message, null)
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Exception: ${e.message}")
            result.error("SERVICE_ERROR", e.message, null)
        }
    }

    private fun isScreenShareServiceRunning(): Boolean {
        return try {
            val manager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
            @Suppress("DEPRECATION")
            manager.getRunningServices(Int.MAX_VALUE)
                .any { it.service.className == ScreenShareService::class.java.name }
        } catch (e: Exception) {
            false
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleCallIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallIntent(intent)
    }

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
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }
}