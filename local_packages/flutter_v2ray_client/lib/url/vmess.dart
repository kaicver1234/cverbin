import 'dart:convert';

import 'package:flutter_v2ray_client/url/url.dart';

/// Vmess URL parser and adapter to produce V2Ray configuration pieces.
///
/// It parses a `vmess://` share link into structured fields and exposes
/// outbound and stream settings compatible with the V2Ray core.
class VmessURL extends V2RayURL {
  /// Creates a VmessURL by parsing the provided vmess share link string.
  ///
  /// Throws [ArgumentError] if the url does not start with `vmess://` or
  /// cannot be decoded into a valid JSON config payload.
  VmessURL({required super.url}) {
    if (!url.startsWith('vmess://')) {
      throw ArgumentError('url is invalid');
    }
    var raw = url.substring(8);
    if (raw.length % 4 > 0) {
      raw += '=' * (4 - raw.length % 4);
    }
    try {
      rawConfig = jsonDecode(utf8.decode(base64Decode(raw)));
    } catch (_) {
      throw ArgumentError('url is invalid');
    }
    final sni = super.populateTransportSettings(
      transport: rawConfig['net'],
      headerType: rawConfig['type'],
      host: rawConfig['host'],
      path: rawConfig['path'],
      seed: rawConfig['path'],
      quicSecurity: rawConfig['host'],
      key: rawConfig['path'],
      mode: rawConfig['type'],
      serviceName: rawConfig['path'],
    );
    final String? fingerprint =
        (rawConfig['fp'] != null && rawConfig['fp'] != '')
            ? rawConfig['fp']
            : streamSetting['tlsSettings']?['fingerprint'];
    super.populateTlsSettings(
      streamSecurity: rawConfig['tls'],
      allowInsecure: allowInsecure,
      sni: sni,
      fingerprint: fingerprint,
      alpns: rawConfig['alpn'],
      publicKey: null,
      shortId: null,
      spiderX: null,
    );
  }

  /// Raw configuration decoded from the vmess URL payload.
  late final Map<String, dynamic> rawConfig;

  /// Human-readable remark (ps field) for this server.
  @override
  String get remark => rawConfig['ps'];

  /// Server address (add field). Returns empty string if missing.
  @override
  String get address => rawConfig['add'] ?? '';

  /// Server port parsed from the config. Falls back to [super.port] if absent.
  @override
  int get port => int.tryParse(rawConfig['port'].toString()) ?? super.port;

  /// Outbound configuration map for the vmess protocol used by V2Ray core.
  @override
  Map<String, dynamic> get outbound1 => {
        'tag': 'proxy',
        'protocol': 'vmess',
        'settings': {
          'vnext': [
            {
              'address': address,
              'port': port,
              'users': [
                {
                  'id': rawConfig['id'] ?? '',
                  'alterId': int.tryParse(rawConfig['aid'].toString()) ?? 0,
                  'security': (rawConfig['scy']?.isEmpty ?? true)
                      ? security
                      : rawConfig['scy'],
                  'level': level,
                  'encryption': '',
                  'flow': ''
                }
              ]
            }
          ],
          'servers': null,
          'response': null,
          'network': null,
          'address': null,
          'port': null,
          'domainStrategy': null,
          'redirect': null,
          'userLevel': null,
          'inboundTag': null,
          'secretKey': null,
          'peers': null
        },
        'streamSettings': streamSetting,
        'proxySettings': null,
        'sendThrough': null,
        'mux': {
          'enabled': false,
          'concurrency': 8,
        }
      };
}
