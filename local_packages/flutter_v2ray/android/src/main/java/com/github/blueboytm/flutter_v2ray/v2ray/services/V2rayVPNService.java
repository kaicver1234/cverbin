package com.github.blueboytm.flutter_v2ray.v2ray.services;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.LocalSocket;
import android.net.LocalSocketAddress;
import android.net.VpnService;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import com.github.blueboytm.flutter_v2ray.v2ray.core.V2rayCoreManager;
import com.github.blueboytm.flutter_v2ray.v2ray.interfaces.V2rayServicesListener;
import com.github.blueboytm.flutter_v2ray.v2ray.utils.AppConfigs;
import com.github.blueboytm.flutter_v2ray.v2ray.utils.V2rayConfig;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileDescriptor;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;

public class V2rayVPNService extends VpnService implements V2rayServicesListener {
    private static final String TAG = "V2rayVPNService";
    private static final String PREFS_NAME = "V2rayVPNPrefs";
    private static final String KEY_V2RAY_CONFIG = "v2ray_config";
    
    private ParcelFileDescriptor mInterface;
    private Process process;
    private V2rayConfig v2rayConfig;
    private boolean isRunning = true;

    @Override
    public void onCreate() {
        super.onCreate();
        V2rayCoreManager.getInstance().setUpListener(this);
    }

    private void saveConfig(V2rayConfig config) {
        try {
            SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ObjectOutputStream oos = new ObjectOutputStream(baos);
            oos.writeObject(config);
            oos.close();
            String configString;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                configString = Base64.getEncoder().encodeToString(baos.toByteArray());
            } else {
                configString = android.util.Base64.encodeToString(baos.toByteArray(), android.util.Base64.DEFAULT);
            }
            prefs.edit().putString(KEY_V2RAY_CONFIG, configString).apply();
            Log.d(TAG, "Config saved successfully");
        } catch (Exception e) {
            Log.e(TAG, "Failed to save config", e);
        }
    }

    private V2rayConfig loadConfig() {
        try {
            SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            String configString = prefs.getString(KEY_V2RAY_CONFIG, null);
            if (configString == null) {
                Log.d(TAG, "No saved config found");
                return null;
            }
            byte[] bytes;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                bytes = Base64.getDecoder().decode(configString);
            } else {
                bytes = android.util.Base64.decode(configString, android.util.Base64.DEFAULT);
            }
            ByteArrayInputStream bais = new ByteArrayInputStream(bytes);
            ObjectInputStream ois = new ObjectInputStream(bais);
            V2rayConfig config = (V2rayConfig) ois.readObject();
            ois.close();
            Log.d(TAG, "Config loaded successfully");
            return config;
        } catch (Exception e) {
            Log.e(TAG, "Failed to load config", e);
            return null;
        }
    }

    private void clearConfig() {
        try {
            SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            prefs.edit().remove(KEY_V2RAY_CONFIG).apply();
            Log.d(TAG, "Config cleared");
        } catch (Exception e) {
            Log.e(TAG, "Failed to clear config", e);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) {
            Log.d(TAG, "Intent is null, trying to restore from saved config");
            v2rayConfig = loadConfig();
            if (v2rayConfig != null) {
                Log.d(TAG, "Restored config from preferences, restarting VPN");
                if (V2rayCoreManager.getInstance().isV2rayCoreRunning()) {
                    V2rayCoreManager.getInstance().stopCore();
                }
                if (V2rayCoreManager.getInstance().startCore(v2rayConfig)) {
                    Log.d(TAG, "V2ray core started successfully after restore");
                } else {
                    Log.e(TAG, "Failed to start V2ray core after restore");
                    clearConfig();
                    this.onDestroy();
                }
            } else {
                Log.e(TAG, "No saved config available, stopping service");
                this.onDestroy();
            }
            return START_STICKY;
        }

        AppConfigs.V2RAY_SERVICE_COMMANDS startCommand = (AppConfigs.V2RAY_SERVICE_COMMANDS) intent.getSerializableExtra("COMMAND");
        if (startCommand == null) {
            Log.d(TAG, "Command is null, trying to restore from saved config");
            v2rayConfig = loadConfig();
            if (v2rayConfig != null) {
                Log.d(TAG, "Restored config from preferences, restarting VPN");
                if (V2rayCoreManager.getInstance().isV2rayCoreRunning()) {
                    V2rayCoreManager.getInstance().stopCore();
                }
                if (V2rayCoreManager.getInstance().startCore(v2rayConfig)) {
                    Log.d(TAG, "V2ray core started successfully after restore");
                } else {
                    Log.e(TAG, "Failed to start V2ray core after restore");
                    clearConfig();
                    this.onDestroy();
                }
            } else {
                Log.e(TAG, "No saved config available, stopping service");
                this.onDestroy();
            }
            return START_STICKY;
        }

        if (startCommand.equals(AppConfigs.V2RAY_SERVICE_COMMANDS.START_SERVICE)) {
            v2rayConfig = (V2rayConfig) intent.getSerializableExtra("V2RAY_CONFIG");
            if (v2rayConfig == null) {
                Log.e(TAG, "V2ray config is null");
                this.onDestroy();
                return START_STICKY;
            }
            saveConfig(v2rayConfig);
            if (V2rayCoreManager.getInstance().isV2rayCoreRunning()) {
                V2rayCoreManager.getInstance().stopCore();
            }
            if (V2rayCoreManager.getInstance().startCore(v2rayConfig)) {
                Log.d(TAG, "V2ray core started successfully");
            } else {
                Log.e(TAG, "Failed to start V2ray core");
                this.onDestroy();
            }
        } else if (startCommand.equals(AppConfigs.V2RAY_SERVICE_COMMANDS.STOP_SERVICE)) {
            V2rayCoreManager.getInstance().stopCore();
            AppConfigs.V2RAY_CONFIG = null;
            clearConfig();
        } else if (startCommand.equals(AppConfigs.V2RAY_SERVICE_COMMANDS.MEASURE_DELAY)) {
            new Thread(() -> {
                Intent sendB = new Intent("CONNECTED_V2RAY_SERVER_DELAY");
                sendB.putExtra("DELAY", String.valueOf(V2rayCoreManager.getInstance().getConnectedV2rayServerDelay()));
                sendBroadcast(sendB);
            }, "MEASURE_CONNECTED_V2RAY_SERVER_DELAY").start();
        } else {
            this.onDestroy();
        }
        return START_STICKY;
    }

    private void stopAllProcess() {
        stopForeground(true);
        isRunning = false;
        if (process != null) {
            process.destroy();
        }
        V2rayCoreManager.getInstance().stopCore();
        clearConfig();
        try {
            stopSelf();
        } catch (Exception e) {
            Log.e(TAG, "Failed to stop self", e);
        }
        try {
            mInterface.close();
        } catch (Exception e) {
            Log.e(TAG, "Failed to close interface", e);
        }

    }

    private void setup() {
        Intent prepare_intent = prepare(this);
        if (prepare_intent != null) {
            return;
        }
        Builder builder = new Builder();
        builder.setSession(v2rayConfig.REMARK);
        builder.setMtu(1500);
        builder.addAddress("26.26.26.1", 30);

        if (v2rayConfig.BYPASS_SUBNETS == null || v2rayConfig.BYPASS_SUBNETS.isEmpty()) {
            builder.addRoute("0.0.0.0", 0);
        } else {
            for (String subnet : v2rayConfig.BYPASS_SUBNETS) {
                String[] parts = subnet.split("/");
                if (parts.length == 2) {
                    String address = parts[0];
                    int prefixLength = Integer.parseInt(parts[1]);
                    builder.addRoute(address, prefixLength);
                }
            }
        }
        if (v2rayConfig.BLOCKED_APPS != null) {
            for (int i = 0; i < v2rayConfig.BLOCKED_APPS.size(); i++) {
                try {
                    builder.addDisallowedApplication(v2rayConfig.BLOCKED_APPS.get(i));
                } catch (Exception e) {
                    //ignore
                }
            }
        }
        try {
            JSONObject json = new JSONObject(v2rayConfig.V2RAY_FULL_JSON_CONFIG);
            JSONObject dnsObject = json.getJSONObject("dns");
            JSONArray serversArray = dnsObject.getJSONArray("servers");
            for (int i = 0; i < serversArray.length(); i++) {
                String server = serversArray.getString(i);
                builder.addDnsServer(server);
            }
        } catch (JSONException e) {
            e.printStackTrace();
        }
        try {
            mInterface.close();
        } catch (Exception e) {
            //ignore
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false);
        }

        try {
            mInterface = builder.establish();
            isRunning = true;
            runTun2socks();
        } catch (Exception e) {
            stopAllProcess();
        }

    }

    private void runTun2socks() {
        ArrayList<String> cmd = new ArrayList<>(Arrays.asList(new File(getApplicationInfo().nativeLibraryDir, "libtun2socks.so").getAbsolutePath(),
                "--netif-ipaddr", "26.26.26.2",
                "--netif-netmask", "255.255.255.252",
                "--socks-server-addr", "127.0.0.1:" + v2rayConfig.LOCAL_SOCKS5_PORT,
                "--tunmtu", "1500",
                "--sock-path", "sock_path",
                "--enable-udprelay",
                "--loglevel", "error"));
        try {
            ProcessBuilder processBuilder = new ProcessBuilder(cmd);
            processBuilder.redirectErrorStream(true);
            process = processBuilder.directory(getApplicationContext().getFilesDir()).start();
            new Thread(() -> {
                try {
                    process.waitFor();
                    if (isRunning) {
                        runTun2socks();
                    }
                } catch (InterruptedException e) {
                    //ignore
                }
            }, "Tun2socks_Thread").start();
            sendFileDescriptor();
        } catch (Exception e) {
            Log.e("VPN_SERVICE", "FAILED=>", e);
            this.onDestroy();
        }
    }

    private void sendFileDescriptor() {
        String localSocksFile = new File(getApplicationContext().getFilesDir(), "sock_path").getAbsolutePath();
        FileDescriptor tunFd = mInterface.getFileDescriptor();
        new Thread(() -> {
            int tries = 0;
            while (true) {
                try {
                    Thread.sleep(50L * tries);
                    LocalSocket clientLocalSocket = new LocalSocket();
                    clientLocalSocket.connect(new LocalSocketAddress(localSocksFile, LocalSocketAddress.Namespace.FILESYSTEM));
                    if (!clientLocalSocket.isConnected()) {
                        Log.e("SOCK_FILE", "Unable to connect to localSocksFile [" + localSocksFile + "]");
                    } else {
                        Log.e("SOCK_FILE", "connected to sock file [" + localSocksFile + "]");
                    }
                    OutputStream clientOutStream = clientLocalSocket.getOutputStream();
                    clientLocalSocket.setFileDescriptorsForSend(new FileDescriptor[]{tunFd});
                    clientOutStream.write(32);
                    clientLocalSocket.setFileDescriptorsForSend(null);
                    clientLocalSocket.shutdownOutput();
                    clientLocalSocket.close();
                    break;
                } catch (Exception e) {
                    Log.e(V2rayVPNService.class.getSimpleName(), "sendFd failed =>", e);
                    if (tries > 5) break;
                    tries += 1;
                }
            }
        }, "sendFd_Thread").start();
    }


    @Override
    public void onDestroy() {
        super.onDestroy();
    }

    @Override
    public void onRevoke() {
        stopAllProcess();
    }

    @Override
    public boolean onProtect(int socket) {
        return protect(socket);
    }

    @Override
    public Service getService() {
        return this;
    }

    @Override
    public void startService() {
        setup();
    }

    @Override
    public void stopService() {
        stopAllProcess();
    }
}
