import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode that controls how the Per-App Proxy feature routes traffic.
enum PerAppProxyMode {
  /// All apps go through the VPN (default).
  off,

  /// Only the selected apps go through the VPN; everything else uses the
  /// regular connection. Maps to `Builder.addAllowedApplication` on Android.
  includeOnly,

  /// All apps go through the VPN EXCEPT the selected ones. Maps to
  /// `Builder.addDisallowedApplication` on Android. Useful for bypassing
  /// banking apps, local services, etc.
  excludeOnly,
}

class InstalledAppInfo {
  final String packageName;
  final String name;
  final bool isSystemApp;
  final Uint8List? icon;

  const InstalledAppInfo({
    required this.packageName,
    required this.name,
    required this.isSystemApp,
    this.icon,
  });
}

/// State + persistence for the Per-App Proxy feature.
///
/// Selection and mode are persisted to SharedPreferences. The installed-app
/// list is loaded on demand and cached in memory only — it can change at any
/// time (user installs/removes apps), so we don't try to persist it.
class PerAppProxyProvider with ChangeNotifier {
  static const String _modeKey = 'per_app_proxy_mode';
  static const String _selectedKey = 'per_app_proxy_selected';

  static const MethodChannel _appListChannel =
      MethodChannel('com.tiksarvpn.app/app_list');

  PerAppProxyMode _mode = PerAppProxyMode.off;
  Set<String> _selectedPackages = <String>{};

  List<InstalledAppInfo> _installedApps = const [];
  bool _isLoadingApps = false;
  String? _loadError;

  /// Notifier called by the v2ray provider when settings that affect the
  /// running tunnel change and a reconnect is required to apply them.
  ///
  /// Set by the v2ray provider via [setReconnectCallback]. We never invoke it
  /// directly from setters — it's invoked from [applyAndPersist] so the user
  /// can stage changes inside the settings screen without reconnecting on
  /// every checkbox toggle.
  VoidCallback? _reconnectCallback;

  PerAppProxyMode get mode => _mode;
  Set<String> get selectedPackages => Set.unmodifiable(_selectedPackages);
  List<InstalledAppInfo> get installedApps => _installedApps;
  bool get isLoadingApps => _isLoadingApps;
  String? get loadError => _loadError;
  int get selectedCount => _selectedPackages.length;

  /// Returns the list of packages to pass as `blockedApps` to v2ray. Null
  /// means "no blocking" (route everything through the VPN).
  List<String>? get blockedAppsForVpn {
    if (_mode != PerAppProxyMode.excludeOnly || _selectedPackages.isEmpty) {
      return null;
    }
    return _selectedPackages.toList(growable: false);
  }

  /// Returns the list of packages to pass as `allowedApps` to v2ray. Null
  /// means "no per-app allow-list" (route everything through the VPN).
  List<String>? get allowedAppsForVpn {
    if (_mode != PerAppProxyMode.includeOnly || _selectedPackages.isEmpty) {
      return null;
    }
    return _selectedPackages.toList(growable: false);
  }

  void setReconnectCallback(VoidCallback? callback) {
    _reconnectCallback = callback;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMode = prefs.getString(_modeKey);
    if (savedMode != null) {
      _mode = PerAppProxyMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => PerAppProxyMode.off,
      );
    }

    final savedSelection = prefs.getStringList(_selectedKey);
    if (savedSelection != null) {
      _selectedPackages = savedSelection.toSet();
    }

    notifyListeners();
  }

  /// Loads the installed apps from the native side. Safe to call multiple
  /// times — re-uses the cached list when possible. Pass [force] to refresh.
  Future<void> loadInstalledApps({bool force = false, bool withIcons = true}) async {
    if (!force && _installedApps.isNotEmpty) return;
    if (_isLoadingApps) return;

    _isLoadingApps = true;
    _loadError = null;
    notifyListeners();

    try {
      if (defaultTargetPlatform != TargetPlatform.android) {
        _installedApps = const [];
        _loadError = 'Per-App Proxy is only available on Android';
        return;
      }

      final List<dynamic> result = await _appListChannel.invokeMethod(
        'getInstalledApps',
        {'withIcons': withIcons},
      );

      final apps = <InstalledAppInfo>[];
      for (final raw in result) {
        if (raw is! Map) continue;
        final map = Map<dynamic, dynamic>.from(raw);
        final pkg = map['packageName'];
        final name = map['name'];
        if (pkg is! String || name is! String) continue;

        Uint8List? iconBytes;
        final iconRaw = map['icon'];
        if (iconRaw is Uint8List) {
          iconBytes = iconRaw;
        } else if (iconRaw is List) {
          iconBytes = Uint8List.fromList(iconRaw.cast<int>());
        }

        apps.add(InstalledAppInfo(
          packageName: pkg,
          name: name,
          isSystemApp: (map['isSystemApp'] as bool?) ?? false,
          icon: iconBytes,
        ));
      }
      _installedApps = apps;
    } catch (e) {
      _loadError = 'Failed to load apps: $e';
      _installedApps = const [];
    } finally {
      _isLoadingApps = false;
      notifyListeners();
    }
  }

  /// In-memory toggle. Persist + apply via [applyAndPersist].
  void togglePackage(String packageName) {
    if (_selectedPackages.contains(packageName)) {
      _selectedPackages.remove(packageName);
    } else {
      _selectedPackages.add(packageName);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedPackages.isEmpty) return;
    _selectedPackages.clear();
    notifyListeners();
  }

  /// In-memory mode change. Persist + apply via [applyAndPersist].
  void setMode(PerAppProxyMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  /// Persist the current state and ask the v2ray provider to reconnect if the
  /// VPN is currently up (so the new routing rules take effect).
  Future<void> applyAndPersist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, _mode.name);
    await prefs.setStringList(_selectedKey, _selectedPackages.toList());

    // Ask the v2ray provider to reconnect if needed. The callback itself
    // checks whether the VPN is currently active.
    _reconnectCallback?.call();
  }
}
