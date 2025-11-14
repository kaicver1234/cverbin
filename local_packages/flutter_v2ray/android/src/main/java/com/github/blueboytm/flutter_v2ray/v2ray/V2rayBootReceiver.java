package com.github.blueboytm.flutter_v2ray.v2ray;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;

import com.github.blueboytm.flutter_v2ray.v2ray.services.V2rayVPNService;

public class V2rayBootReceiver extends BroadcastReceiver {
    private static final String TAG = "V2rayBootReceiver";
    private static final String PREFS_NAME = "V2rayVPNPrefs";
    private static final String KEY_V2RAY_CONFIG = "v2ray_config";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction()) ||
            "android.intent.action.QUICKBOOT_POWERON".equals(intent.getAction()) ||
            Intent.ACTION_MY_PACKAGE_REPLACED.equals(intent.getAction())) {
            
            Log.d(TAG, "Device boot or package update detected, checking for saved VPN config");
            
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            String configString = prefs.getString(KEY_V2RAY_CONFIG, null);
            
            if (configString != null) {
                Log.d(TAG, "Found saved VPN config, attempting to restore connection");
                
                Intent serviceIntent = new Intent(context, V2rayVPNService.class);
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent);
                    } else {
                        context.startService(serviceIntent);
                    }
                    Log.d(TAG, "VPN service restart initiated successfully");
                } catch (Exception e) {
                    Log.e(TAG, "Failed to restart VPN service", e);
                }
            } else {
                Log.d(TAG, "No saved VPN config found, skipping auto-reconnect");
            }
        }
    }
}
