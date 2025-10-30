package com.tiksarvpn.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tiksarvpn.app/vpn_control"
    private var vpnControlChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle intent in onCreate for fresh app starts
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppListMethodChannel.registerWith(flutterEngine, context)
        PingMethodChannel.registerWith(flutterEngine, context)
        SettingsMethodChannel.registerWith(flutterEngine, context)
        
        // Create VPN control channel for notification disconnect
        vpnControlChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Update the intent and handle it
        setIntent(intent)
        handleIntent(intent)
    }
    
    override fun onResume() {
        super.onResume()
        // Handle any pending intents
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        if (intent?.action == "FROM_DISCONNECT_BTN") {
            // Send message to Flutter to disconnect VPN
            vpnControlChannel?.invokeMethod("disconnectFromNotification", null)
            // Clear the intent action to prevent repeated handling
            intent.action = null
        }
    }
}
