package com.tiksarvpn.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SettingsMethodChannel(private val context: Context) : MethodCallHandler {
    companion object {
        const val CHANNEL = "com.tiksarvpn.app/settings"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(SettingsMethodChannel(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d("SettingsMethodChannel", "Method called: ${call.method}")
        when (call.method) {
            "openBatteryOptimizationSettings" -> {
                try {
                    openBatteryOptimizationSettings()
                    result.success(true)
                } catch (e: Exception) {
                    Log.e("SettingsMethodChannel", "Failed to open battery optimization settings", e)
                    result.error("SETTINGS_ERROR", "Failed to open battery optimization settings", e.message)
                }
            }
            "openAppSettings" -> {
                try {
                    openAppSettings()
                    result.success(true)
                } catch (e: Exception) {
                    Log.e("SettingsMethodChannel", "Failed to open app settings", e)
                    result.error("SETTINGS_ERROR", "Failed to open app settings", e.message)
                }
            }
            "openGeneralBatterySettings" -> {
                try {
                    openGeneralBatterySettings()
                    result.success(true)
                } catch (e: Exception) {
                    Log.e("SettingsMethodChannel", "Failed to open general battery settings", e)
                    result.error("SETTINGS_ERROR", "Failed to open general battery settings", e.message)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun openBatteryOptimizationSettings() {
        Log.d("SettingsMethodChannel", "Opening battery optimization settings")
        try {
            val intent = Intent()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Try to open battery optimization settings for the specific app
                intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                intent.data = Uri.parse("package:${context.packageName}")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                Log.d("SettingsMethodChannel", "Starting intent with action: ${intent.action}")
                context.startActivity(intent)
                Log.d("SettingsMethodChannel", "Battery optimization settings intent started successfully")
            } else {
                // Fallback to general app settings for older versions
                Log.d("SettingsMethodChannel", "Android version < M, falling back to app settings")
                openAppSettings()
            }
        } catch (e: Exception) {
            Log.w("SettingsMethodChannel", "Battery optimization settings failed, trying general battery settings", e)
            // If specific battery optimization settings fail, try general battery settings
            try {
                val intent = Intent()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    intent.action = Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                } else {
                    intent.action = Settings.ACTION_APPLICATION_SETTINGS
                }
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                Log.d("SettingsMethodChannel", "Starting fallback intent with action: ${intent.action}")
                context.startActivity(intent)
                Log.d("SettingsMethodChannel", "Fallback battery settings intent started successfully")
            } catch (e2: Exception) {
                Log.w("SettingsMethodChannel", "General battery settings failed, falling back to app settings", e2)
                // Final fallback to app settings
                openAppSettings()
            }
        }
    }

    private fun openAppSettings() {
        Log.d("SettingsMethodChannel", "Opening app settings")
        try {
            val intent = Intent()
            intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
            intent.data = Uri.fromParts("package", context.packageName, null)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            Log.d("SettingsMethodChannel", "Starting app settings intent for package: ${context.packageName}")
            context.startActivity(intent)
            Log.d("SettingsMethodChannel", "App settings intent started successfully")
        } catch (e: Exception) {
            Log.e("SettingsMethodChannel", "Failed to open app settings", e)
            throw e
        }
    }

    private fun openGeneralBatterySettings() {
        Log.d("SettingsMethodChannel", "Opening general battery settings")
        try {
            val intent = Intent()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                intent.action = Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
            } else {
                intent.action = Settings.ACTION_BATTERY_SAVER_SETTINGS
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            Log.d("SettingsMethodChannel", "Starting general battery settings intent with action: ${intent.action}")
            context.startActivity(intent)
            Log.d("SettingsMethodChannel", "General battery settings intent started successfully")
        } catch (e: Exception) {
            Log.e("SettingsMethodChannel", "Failed to open general battery settings", e)
            throw e
        }
    }
}
