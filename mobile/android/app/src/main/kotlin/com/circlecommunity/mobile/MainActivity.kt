package com.circlecommunity.mobile

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "circle/notification_preferences")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "timezone" -> result.success(TimeZone.getDefault().id)
                    "settings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("unavailable", "Notification settings could not open.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
