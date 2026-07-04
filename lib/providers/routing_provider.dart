import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages geo-bypass routing rules. Controls which traffic should bypass the
/// VPN tunnel and go through the regular network (direct outbound).
///
/// Two layers work together:
///   1. [bypassSubnets] are passed to the Android VpnBuilder and bypass the
///      tunnel at the OS level — most reliable, never enters v2ray core.
///   2. v2ray routing rules (geoip / geosite / domain matching) route traffic
///      inside the core to the direct outbound. Catches DNS-resolved domains
///      that don't map to a static subnet.
///
/// All settings are persisted to SharedPreferences. Validation happens at the
/// setter level so the consumer only ever sees clean data.
class RoutingProvider with ChangeNotifier {
  static const String _bypassIranKey = 'routing_bypass_iran';
  static const String _bypassPrivateKey = 'routing_bypass_private';
  static const String _customSubnetsKey = 'routing_custom_subnets';
  static const String _customDomainsKey = 'routing_custom_domains';
  static const String _blockAdsKey = 'routing_block_ads';

  // RFC1918 + link-local + loopback + multicast + CGNAT. Used when
  // [bypassPrivate] is enabled. Mirrors what every reputable VPN client ships
  // by default so e.g. router admin pages, printers, NAS, mDNS keep working.
  static const List<String> _privateSubnets = [
    '10.0.0.0/8',
    '172.16.0.0/12',
    '192.168.0.0/16',
    '127.0.0.0/8',
    '169.254.0.0/16',
    '224.0.0.0/4',
    '240.0.0.0/4',
    '100.64.0.0/10',
    '::1/128',
    'fc00::/7',
    'fe80::/10',
    'ff00::/8',
  ];

  bool _bypassIran = false;
  bool _bypassPrivate = false;
  bool _blockAds = false;
  List<String> _customSubnets = const [];
  List<String> _customDomains = const [];
  bool _initialized = false;

  bool get bypassIran => _bypassIran;
  bool get bypassPrivate => _bypassPrivate;
  bool get blockAds => _blockAds;
  List<String> get customSubnets => List.unmodifiable(_customSubnets);
  List<String> get customDomains => List.unmodifiable(_customDomains);
  bool get isInitialized => _initialized;

  /// All subnets that should bypass the OS tunnel (passed to startV2Ray
  /// `bypassSubnets`). Combines the private set + user customs when their
  /// respective toggles are on. Returns null when there's nothing to bypass
  /// so the plugin can skip the IPC entirely.
  List<String>? get effectiveBypassSubnets {
    final all = <String>{};
    if (_bypassPrivate) all.addAll(_privateSubnets);
    if (_customSubnets.isNotEmpty) all.addAll(_customSubnets);
    if (all.isEmpty) return null;
    return all.toList(growable: false);
  }

  /// v2ray routing rules to inject into the core config. Built fresh on each
  /// connect — the rule order matters: more specific rules first, catch-all
  /// (proxy) implicitly last via outbound tag chaining.
  List<Map<String, dynamic>> buildRoutingRules() {
    final rules = <Map<String, dynamic>>[];

    // 1) Block ads/trackers. This rule is FIRST so it wins over every bypass
    //    rule below — ad networks are dropped even on otherwise-direct routes.
    //    `category-ads-all` is the standard community ad+tracker list baked
    //    into the bundled geosite.dat; matched domains go to the `blackhole`
    //    outbound (outbound3, defined by the parser) which simply drops them.
    //    Off by default; enabling it never affects normal (non-ad) sites.
    if (_blockAds) {
      rules.add({
        'type': 'field',
        'outboundTag': 'blackhole',
        'domain': ['geosite:category-ads-all'],
      });
    }

    // 2) Bypass private/LAN IPs at the core level too. This is belt-and-
    //    suspenders alongside bypassSubnets: if the OS-level bypass fails
    //    for any reason, the core still routes them direct.
    if (_bypassPrivate) {
      rules.add({
        'type': 'field',
        'outboundTag': 'direct',
        'ip': ['geoip:private'],
      });
    }

    // 3) Bypass Iran traffic (the main user-requested feature).
    if (_bypassIran) {
      rules.add({
        'type': 'field',
        'outboundTag': 'direct',
        'ip': ['geoip:ir'],
      });
      rules.add({
        'type': 'field',
        'outboundTag': 'direct',
        'domain': ['geosite:category-ir', 'regexp:.*\\.ir\$'],
      });
    }

    // 4) User's custom subnets (also bypass via core).
    if (_customSubnets.isNotEmpty) {
      rules.add({
        'type': 'field',
        'outboundTag': 'direct',
        'ip': List<String>.from(_customSubnets),
      });
    }

    // 5) User's custom domains.
    if (_customDomains.isNotEmpty) {
      rules.add({
        'type': 'field',
        'outboundTag': 'direct',
        'domain': List<String>.from(_customDomains),
      });
    }

    return rules;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _bypassIran = prefs.getBool(_bypassIranKey) ?? false;
      _bypassPrivate = prefs.getBool(_bypassPrivateKey) ?? false;
      _blockAds = prefs.getBool(_blockAdsKey) ?? false;
      _customSubnets = (prefs.getStringList(_customSubnetsKey) ?? const [])
          .where(isValidCidr)
          .toList(growable: false);
      _customDomains = (prefs.getStringList(_customDomainsKey) ?? const [])
          .where(isValidDomain)
          .toList(growable: false);
    } catch (e) {
      debugPrint('⚠️ RoutingProvider init failed: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setBypassIran(bool value) async {
    if (_bypassIran == value) return;
    _bypassIran = value;
    notifyListeners();
    await _persistBool(_bypassIranKey, value);
  }

  Future<void> setBypassPrivate(bool value) async {
    if (_bypassPrivate == value) return;
    _bypassPrivate = value;
    notifyListeners();
    await _persistBool(_bypassPrivateKey, value);
  }

  Future<void> setBlockAds(bool value) async {
    if (_blockAds == value) return;
    _blockAds = value;
    notifyListeners();
    await _persistBool(_blockAdsKey, value);
  }

  /// Adds a CIDR subnet. Returns true if added, false if invalid or duplicate.
  Future<bool> addCustomSubnet(String raw) async {
    final cleaned = raw.trim();
    if (!isValidCidr(cleaned)) return false;
    if (_customSubnets.contains(cleaned)) return false;
    _customSubnets = [..._customSubnets, cleaned];
    notifyListeners();
    await _persistList(_customSubnetsKey, _customSubnets);
    return true;
  }

  Future<void> removeCustomSubnet(String value) async {
    if (!_customSubnets.contains(value)) return;
    _customSubnets =
        _customSubnets.where((s) => s != value).toList(growable: false);
    notifyListeners();
    await _persistList(_customSubnetsKey, _customSubnets);
  }

  /// Adds a domain rule. Accepts plain domains (`example.com`), `domain:`,
  /// `full:`, `geosite:`, `regexp:` prefixes. Returns true if added.
  Future<bool> addCustomDomain(String raw) async {
    final cleaned = raw.trim();
    if (!isValidDomain(cleaned)) return false;
    if (_customDomains.contains(cleaned)) return false;
    _customDomains = [..._customDomains, cleaned];
    notifyListeners();
    await _persistList(_customDomainsKey, _customDomains);
    return true;
  }

  Future<void> removeCustomDomain(String value) async {
    if (!_customDomains.contains(value)) return;
    _customDomains =
        _customDomains.where((s) => s != value).toList(growable: false);
    notifyListeners();
    await _persistList(_customDomainsKey, _customDomains);
  }

  Future<void> _persistBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('⚠️ Failed to persist $key: $e');
    }
  }

  Future<void> _persistList(String key, List<String> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, value);
    } catch (e) {
      debugPrint('⚠️ Failed to persist $key: $e');
    }
  }

  // ─── Validation ────────────────────────────────────────────────────────

  /// Validates an IPv4 or IPv6 CIDR. Permissive enough to accept the common
  /// formats users paste from threat-intel sites, strict enough to reject
  /// typos that would later crash v2ray core.
  static bool isValidCidr(String input) {
    final s = input.trim();
    if (s.isEmpty) return false;
    final slash = s.indexOf('/');
    if (slash <= 0 || slash == s.length - 1) return false;
    final ipPart = s.substring(0, slash);
    final prefixPart = s.substring(slash + 1);

    final prefix = int.tryParse(prefixPart);
    if (prefix == null) return false;

    if (ipPart.contains(':')) {
      // IPv6
      if (prefix < 0 || prefix > 128) return false;
      return _isValidIpv6(ipPart);
    }
    // IPv4
    if (prefix < 0 || prefix > 32) return false;
    return _isValidIpv4(ipPart);
  }

  static bool _isValidIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      if (p.isEmpty || p.length > 3) return false;
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  static bool _isValidIpv6(String ip) {
    // Cheap structural check — full IPv6 validation is non-trivial and the
    // v2ray core does its own parsing. We just rule out obvious garbage.
    if (ip.isEmpty || ip.length > 45) return false;
    if (!RegExp(r'^[0-9a-fA-F:]+$').hasMatch(ip)) return false;
    // Must contain at least one colon and no triple colons.
    if (!ip.contains(':')) return false;
    if (ip.contains(':::')) return false;
    return true;
  }

  /// Validates a v2ray-routing domain rule. Accepts:
  /// - plain hostname: `example.com`
  /// - `domain:example.com` (suffix match)
  /// - `full:host.example.com` (exact)
  /// - `regexp:^pattern\$`
  /// - `geosite:cn`
  static bool isValidDomain(String input) {
    final s = input.trim();
    if (s.isEmpty || s.length > 253) return false;

    // Prefixed rules: accept anything non-empty after the prefix; v2ray will
    // surface its own parse error if the inner value is malformed.
    for (final prefix in const ['domain:', 'full:', 'regexp:', 'geosite:']) {
      if (s.startsWith(prefix)) {
        final rest = s.substring(prefix.length).trim();
        return rest.isNotEmpty;
      }
    }

    // Plain domain: at least one dot, ASCII letters / digits / hyphen / dot.
    if (!s.contains('.')) return false;
    if (s.startsWith('.') || s.endsWith('.')) return false;
    return RegExp(r'^[a-zA-Z0-9.\-]+$').hasMatch(s);
  }
}
