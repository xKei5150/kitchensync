package com.example.kitchensync

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The Android integration harness uses this transient launch value to
        // select a test phase after a real process restart. It neither reads nor
        // writes Firebase/session data.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kitchensync.integration/session_restore",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "phase" -> result.success(intent?.getStringExtra("session_restore_phase"))
                else -> result.notImplemented()
            }
        }
    }
}
