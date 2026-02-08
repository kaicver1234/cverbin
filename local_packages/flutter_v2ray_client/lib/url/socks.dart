import 'dart:convert';

import 'package:flutter_v2ray_client/url/url.dart';

/// Socks URL parser and adapter to produce V2Ray configuration pieces.
///
/// It parses a `socks://` share link into structured fields and exposes
/// outbound and stream settings compatible with the V2Ray core.
class SocksURL extends V2RayURL {
  /// Creates a SocksURL by parsing the provided socks share link string.
  ///
  /// Throws [ArgumentError] if the url does not start with `socks://` or
  /// cannot be decoded into a valid URI.
  SocksURL({required super.url}) {
    if (!url.startsWith('socks://')) {
      throw ArgumentError('url is invalid');
    }
    final temp = Uri.tryParse(url);
    if (temp == null) {
      throw ArgumentError('url is invalid');
    }
    uri = temp;
    if (uri.userInfo.isNotEmpty) {
      final userpass = utf8.decode(base64Decode(uri.userInfo));
      username = userpass.split(':')[0];
      password = userpass.substring(username!.length + 1);
    } else {
      username = null;
      password = null;
    }
  }

  /// Username extracted from the URI user info (base64 decoded).
  late final String? username;

  /// Password extracted from the URI user info (base64 decoded).
  late final String? password;

  /// The parsed URI object from the socks URL.
  late final Uri uri;

  /// Server address extracted from the URI host.
  @override
  String get address => uri.host;

  /// Server port parsed from the URI. Falls back to [super.port] if absent.
  @override
  int get port => uri.hasPort ? uri.port : super.port;

  /// Human-readable remark decoded from the URI fragment.
  @override
  String get remark => Uri.decodeFull(uri.fragment.replaceAll('+', '%20'));

  /// Outbound configuration map for the socks protocol used by V2Ray core.
  @override
  Map<String, dynamic> get outbound1 => {
        'protocol': 'socks',
        'settings': {
          'servers': [
            {
              'address': address,
              'level': level,
              'method': 'chacha20-poly1305',
              'ota': false,
              'password': '',
              'port': port,
              'users': [
                {'level': level, 'user': username, 'pass': password}
              ]
            }
          ]
        },
        'streamSettings': streamSetting,
        'tag': 'proxy',
        'mux': {'concurrency': 8, 'enabled': false},
      };
}
