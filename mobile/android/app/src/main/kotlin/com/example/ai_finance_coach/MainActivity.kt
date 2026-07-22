package com.example.ai_finance_coach

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val securityChannel = "com.projectjhob/security"

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
