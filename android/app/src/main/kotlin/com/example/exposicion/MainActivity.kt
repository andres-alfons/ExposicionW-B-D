package com.example.exposicion

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.os.Build

class MainActivity : FlutterActivity() {
    private fun networkSettingsIntent(): Intent = Intent(
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            Settings.Panel.ACTION_INTERNET_CONNECTIVITY
        else Settings.ACTION_WIRELESS_SETTINGS
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Solo abre una pantalla del sistema; nunca modifica los radios.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "conectalab/network_settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "canOpen" -> result.success(networkSettingsIntent().resolveActivity(packageManager) != null)
                    "open" -> {
                        try {
                            startActivity(networkSettingsIntent())
                            result.success(true)
                        } catch (_: android.content.ActivityNotFoundException) {
                            result.success(false)
                        } catch (_: SecurityException) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
