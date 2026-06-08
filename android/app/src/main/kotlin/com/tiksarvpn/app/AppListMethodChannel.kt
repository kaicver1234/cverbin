package com.tiksarvpn.app

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream

class AppListMethodChannel(private val context: Context) : MethodCallHandler {
    companion object {
        const val CHANNEL = "com.tiksarvpn.app/app_list"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(AppListMethodChannel(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getInstalledApps" -> {
                try {
                    val includeIcons = (call.argument<Boolean>("withIcons")) ?: false
                    val packageManager = context.packageManager
                    val installedApps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)

                    val appList = mutableListOf<Map<String, Any>>()

                    for (appInfo in installedApps) {
                        // Skip system apps that don't have a launcher
                        if ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0) {
                            val launchIntent = packageManager.getLaunchIntentForPackage(appInfo.packageName)
                            if (launchIntent == null) {
                                continue
                            }
                        }

                        // Skip our own app — it's always allowed implicitly through the VPN
                        if (appInfo.packageName == context.packageName) {
                            continue
                        }

                        val appName = packageManager.getApplicationLabel(appInfo).toString()
                        val packageName = appInfo.packageName

                        val entry = mutableMapOf<String, Any>(
                            "name" to appName,
                            "packageName" to packageName,
                            "isSystemApp" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
                        )

                        if (includeIcons) {
                            try {
                                val icon = packageManager.getApplicationIcon(appInfo)
                                val bytes = drawableToPngBytes(icon)
                                if (bytes != null) {
                                    entry["icon"] = bytes
                                }
                            } catch (_: Exception) {
                                // Skip icon if it cannot be rendered
                            }
                        }

                        appList.add(entry)
                    }

                    val sortedAppList = appList.sortedBy { (it["name"] as? String)?.lowercase() ?: "" }

                    result.success(sortedAppList)
                } catch (e: Exception) {
                    result.error("APP_LIST_ERROR", "Failed to get installed apps", e.message)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun drawableToPngBytes(drawable: Drawable): ByteArray? {
        return try {
            val size = 64
            val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
                Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
            } else {
                val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                drawable.setBounds(0, 0, size, size)
                drawable.draw(canvas)
                bmp
            }
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 75, stream)
            stream.toByteArray()
        } catch (_: Exception) {
            null
        }
    }
}
