package com.localtools.deposit_renewal_manager

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "deposit_renewal_manager/settings"
        ).setMethodCallHandler { call, result ->
            if (call.method != "openAppSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val notificationSettings = Intent(
                Settings.ACTION_APP_NOTIFICATION_SETTINGS
            ).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(notificationSettings)
                result.success(true)
            } catch (_: ActivityNotFoundException) {
                openApplicationDetailsSettings(result)
            } catch (_: Exception) {
                openApplicationDetailsSettings(result)
            }
        }
    }

    private fun openApplicationDetailsSettings(result: MethodChannel.Result) {
        val detailsSettings = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(detailsSettings)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }
}
