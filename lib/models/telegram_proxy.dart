import 'dart:convert';

class TelegramProxy {
  final String host;
  final int port;
  final String secret;
  final String country;
  final String provider;
  final int uptime;
  final int addTime;
  final int updateTime;
  final int ping;

  TelegramProxy({
    required this.host,
    required this.port,
    required this.secret,
    required this.country,
    required this.provider,
    required this.uptime,
    required this.addTime,
    required this.updateTime,
    required this.ping,
  });

  factory TelegramProxy.fromJson(Map<String, dynamic> json) {
    // Helper function to safely convert numeric values to int
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        try {
          return int.parse(value);
        } catch (_) {
          return 0;
        }
      }
      return 0;
    }

    return TelegramProxy(
      host: json['host'] ?? '',
      port: toInt(json['port']),
      secret: json['secret'] ?? '',
      country: json['country'] ?? '',
      provider: json['provider'] ?? '',
      uptime: toInt(json['uptime']),
      addTime: toInt(json['addTime']),
      updateTime: toInt(json['updateTime']),
      ping: toInt(json['ping']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'secret': secret,
      'country': country,
      'provider': provider,
      'uptime': uptime,
      'addTime': addTime,
      'updateTime': updateTime,
      'ping': ping,
    };
  }

  String get telegramUrl {
    return 'tg://proxy?server=$host&port=$port&secret=$secret';
  }

  String get telegramHttpsUrl {
    return 'https://t.me/proxy?server=$host&port=$port&secret=$secret';
  }

  @override
  String toString() {
    return 'TelegramProxy{host: $host, port: $port, country: $country, ping: $ping}';
  }
}

List<TelegramProxy> parseTelegramProxies(String jsonString) {
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.map((json) => TelegramProxy.fromJson(json)).toList();
}
