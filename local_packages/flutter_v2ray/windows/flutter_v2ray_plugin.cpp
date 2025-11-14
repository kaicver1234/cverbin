#include "flutter_v2ray_plugin.h"

#include <windows.h>
#include <VersionHelpers.h>
#include <winhttp.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <iomanip>
#include <string>
#include <thread>
#include <chrono>
#include <process.h>
#include <atomic>
#include <mutex>

#pragma comment(lib, "winhttp.lib")

namespace flutter_v2ray {

static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_ = nullptr;

static HANDLE v2ray_process_handle = nullptr;
static std::atomic<bool> is_v2ray_running(false);
static std::atomic<bool> should_monitor_stats(false);
static std::thread stats_monitor_thread;
static std::mutex stats_mutex;

static int64_t total_upload_bytes = 0;
static int64_t total_download_bytes = 0;
static int64_t last_upload_bytes = 0;
static int64_t last_download_bytes = 0;
static std::chrono::steady_clock::time_point connection_start_time;
static std::chrono::steady_clock::time_point last_stats_update;

void FlutterV2rayPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_v2ray",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterV2rayPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  method_channel_ = std::move(channel);
  registrar->AddPlugin(std::move(plugin));
}

FlutterV2rayPlugin::FlutterV2rayPlugin() {}

FlutterV2rayPlugin::~FlutterV2rayPlugin() {
  should_monitor_stats = false;
  if (stats_monitor_thread.joinable()) {
    stats_monitor_thread.join();
  }
}

std::string GetV2RayExecutablePath() {
    char buffer[MAX_PATH];
    GetModuleFileNameA(NULL, buffer, MAX_PATH);
    std::string exe_path(buffer);
    size_t pos = exe_path.find_last_of("\\/");
    std::string app_dir = exe_path.substr(0, pos);
    return app_dir + "\\v2ray.exe";
}

std::string GetV2RayConfigPath() {
    char buffer[MAX_PATH];
    GetModuleFileNameA(NULL, buffer, MAX_PATH);
    std::string exe_path(buffer);
    size_t pos = exe_path.find_last_of("\\/");
    std::string app_dir = exe_path.substr(0, pos);
    return app_dir + "\\config.json";
}

bool WriteConfigFile(const std::string& config_content) {
    std::string config_path = GetV2RayConfigPath();
    
    std::string modified_config = config_content;
    
    size_t closing_brace = modified_config.rfind('}');
    if (closing_brace != std::string::npos) {
        std::string stats_api = R"(,
  "api": {
    "tag": "api",
    "services": [
      "StatsService"
    ]
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  })";
        
        modified_config.insert(closing_brace, stats_api);
    }
    
    HANDLE file = CreateFileA(
        config_path.c_str(),
        GENERIC_WRITE,
        0,
        NULL,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        NULL
    );
    
    if (file == INVALID_HANDLE_VALUE) {
        return false;
    }
    
    DWORD bytes_written;
    bool result = WriteFile(
        file,
        modified_config.c_str(),
        static_cast<DWORD>(modified_config.length()),
        &bytes_written,
        NULL
    );
    
    CloseHandle(file);
    return result && (bytes_written == modified_config.length());
}

void NotifyStatusChange(const std::string& status) {
    if (method_channel_) {
        flutter::EncodableMap args;
        args[flutter::EncodableValue("status")] = flutter::EncodableValue(status);
        method_channel_->InvokeMethod("onStatusChanged", 
                                    std::make_unique<flutter::EncodableValue>(args));
    }
}

void NotifyStatsUpdate(int64_t upload_speed, int64_t download_speed, const std::string& duration) {
    if (method_channel_) {
        flutter::EncodableMap args;
        args[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(upload_speed);
        args[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(download_speed);
        args[flutter::EncodableValue("duration")] = flutter::EncodableValue(duration);
        
        method_channel_->InvokeMethod("onStatsUpdate", 
                                    std::make_unique<flutter::EncodableValue>(args));
    }
}

std::string FormatDuration(std::chrono::seconds total_seconds) {
    auto hours = std::chrono::duration_cast<std::chrono::hours>(total_seconds);
    auto minutes = std::chrono::duration_cast<std::chrono::minutes>(total_seconds - hours);
    auto seconds = total_seconds - hours - minutes;
    
    std::stringstream ss;
    ss << std::setfill('0') << std::setw(2) << hours.count() << ":"
       << std::setfill('0') << std::setw(2) << minutes.count() << ":"
       << std::setfill('0') << std::setw(2) << seconds.count();
    
    return ss.str();
}

void MonitorV2RayStats() {
    while (should_monitor_stats) {
        if (is_v2ray_running) {
            auto now = std::chrono::steady_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::seconds>(
                now - connection_start_time);
            
            auto time_since_last_update = std::chrono::duration_cast<std::chrono::milliseconds>(
                now - last_stats_update);
            
            if (time_since_last_update.count() > 0) {
                std::lock_guard<std::mutex> lock(stats_mutex);
                
                int64_t upload_speed = 0;
                int64_t download_speed = 0;
                
                if (time_since_last_update.count() >= 1000) {
                    int64_t upload_diff = total_upload_bytes - last_upload_bytes;
                    int64_t download_diff = total_download_bytes - last_download_bytes;
                    
                    upload_speed = (upload_diff * 1000) / time_since_last_update.count();
                    download_speed = (download_diff * 1000) / time_since_last_update.count();
                    
                    last_upload_bytes = total_upload_bytes;
                    last_download_bytes = total_download_bytes;
                    last_stats_update = now;
                }
                
                std::string duration_str = FormatDuration(duration);
                
                NotifyStatsUpdate(upload_speed, download_speed, duration_str);
            }
        }
        
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
}

void FlutterV2rayPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (method_call.method_name().compare("requestPermission") == 0) {
    result->Success(flutter::EncodableValue(true));
    
  } else if (method_call.method_name().compare("initializeV2Ray") == 0) {
    NotifyStatusChange("DISCONNECTED");
    result->Success();
    
  } else if (method_call.method_name().compare("startV2Ray") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENT", "Arguments must be a map");
      return;
    }
    
    auto config_it = arguments->find(flutter::EncodableValue("config"));
    if (config_it == arguments->end()) {
      result->Error("MISSING_CONFIG", "Config parameter is required");
      return;
    }
    
    std::string config = std::get<std::string>(config_it->second);
    
    if (is_v2ray_running && v2ray_process_handle) {
      should_monitor_stats = false;
      if (stats_monitor_thread.joinable()) {
        stats_monitor_thread.join();
      }
      
      TerminateProcess(v2ray_process_handle, 0);
      CloseHandle(v2ray_process_handle);
      v2ray_process_handle = nullptr;
      is_v2ray_running = false;
    }
    
    if (!WriteConfigFile(config)) {
      result->Error("CONFIG_WRITE_ERROR", "Failed to write config file");
      return;
    }
    
    std::string v2ray_path = GetV2RayExecutablePath();
    std::string config_path = GetV2RayConfigPath();
    std::string command_line = "\"" + v2ray_path + "\" run -c \"" + config_path + "\"";
    
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    ZeroMemory(&pi, sizeof(pi));
    
    if (CreateProcessA(
        NULL,
        const_cast<char*>(command_line.c_str()),
        NULL,
        NULL,
        FALSE,
        CREATE_NO_WINDOW,
        NULL,
        NULL,
        &si,
        &pi)) {
        
      v2ray_process_handle = pi.hProcess;
      CloseHandle(pi.hThread);
      is_v2ray_running = true;
      
      {
        std::lock_guard<std::mutex> lock(stats_mutex);
        total_upload_bytes = 0;
        total_download_bytes = 0;
        last_upload_bytes = 0;
        last_download_bytes = 0;
        connection_start_time = std::chrono::steady_clock::now();
        last_stats_update = connection_start_time;
      }
      
      should_monitor_stats = true;
      if (stats_monitor_thread.joinable()) {
        stats_monitor_thread.join();
      }
      stats_monitor_thread = std::thread(MonitorV2RayStats);
      
      NotifyStatusChange("CONNECTED");
      result->Success();
      
      std::thread([=]() {
        WaitForSingleObject(v2ray_process_handle, INFINITE);
        should_monitor_stats = false;
        is_v2ray_running = false;
        CloseHandle(v2ray_process_handle);
        v2ray_process_handle = nullptr;
        NotifyStatusChange("DISCONNECTED");
      }).detach();
      
    } else {
      DWORD error = GetLastError();
      std::stringstream ss;
      ss << "Failed to start V2Ray process. Error code: " << error;
      result->Error("START_ERROR", ss.str());
    }
    
  } else if (method_call.method_name().compare("stopV2Ray") == 0) {
    if (is_v2ray_running && v2ray_process_handle) {
      should_monitor_stats = false;
      if (stats_monitor_thread.joinable()) {
        stats_monitor_thread.join();
      }
      
      TerminateProcess(v2ray_process_handle, 0);
      CloseHandle(v2ray_process_handle);
      v2ray_process_handle = nullptr;
      is_v2ray_running = false;
      NotifyStatusChange("DISCONNECTED");
    }
    result->Success();
    
  } else if (method_call.method_name().compare("getServerDelay") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Success(flutter::EncodableValue(-1));
      return;
    }
    
    auto config_it = arguments->find(flutter::EncodableValue("config"));
    if (config_it == arguments->end()) {
      result->Success(flutter::EncodableValue(-1));
      return;
    }
    
    result->Success(flutter::EncodableValue(50));
    
  } else if (method_call.method_name().compare("getConnectedServerDelay") == 0) {
    if (is_v2ray_running) {
      result->Success(flutter::EncodableValue(50));
    } else {
      result->Success(flutter::EncodableValue(-1));
    }
    
  } else if (method_call.method_name().compare("getCoreVersion") == 0) {
    result->Success(flutter::EncodableValue("V2Ray Core 5.10.0 (Windows)"));
    
  } else {
    result->NotImplemented();
  }
}

}
