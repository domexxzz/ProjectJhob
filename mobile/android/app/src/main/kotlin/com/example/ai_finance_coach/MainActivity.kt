package com.example.ai_finance_coach

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val securityChannel = "com.projectjhob/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // สร้าง notification channel แบบ IMPORTANCE_HIGH ให้ push เด้งเด่น (heads-up) + มีเสียง
        // FCM (ตอนแอปอยู่พื้นหลัง) จะใช้ channel นี้ผ่าน meta-data ใน AndroidManifest
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "high_importance_channel",
                "การแจ้งเตือนสำคัญ",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "แจ้งเตือนการเงินจากพี่เงิน (เตือนงบ/สลิป/ครบกำหนด)"
                enableVibration(true)
            }
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Protect the first frame by default. Flutter applies the saved user
        // preference immediately after startup and may clear this flag.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            securityChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureScreen" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
