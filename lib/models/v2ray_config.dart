import '../utils/country_flags.dart';

class V2RayConfig {
  final String id;
  final String remark;
  final String address;
  final int port;
  final String configType; // vmess, vless, etc.
  final String fullConfig;
  final String? countryCode; // ISO 3166-1 alpha-2 code (e.g., US, DE, FR)
  bool isConnected;

  V2RayConfig({
    required this.id,
    required this.remark,
    required this.address,
    required this.port,
    required this.configType,
    required this.fullConfig,
    this.countryCode,
    this.isConnected = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'remark': remark,
      'address': address,
      'port': port,
      'configType': configType,
      'fullConfig': fullConfig,
      'countryCode': countryCode,
      'isConnected': isConnected,
    };
  }

  factory V2RayConfig.fromJson(Map<String, dynamic> json) {
    return V2RayConfig(
      id: json['id'],
      remark: json['remark'],
      address: json['address'],
      port: json['port'],
      configType: json['configType'],
      fullConfig: json['fullConfig'],
      countryCode: json['countryCode'],
      isConnected: json['isConnected'] ?? false,
    );
  }
  
  // Get country flag emoji from country code
  String get countryFlag {
    return CountryFlags.getFlagEmoji(countryCode);
  }
  
  // Get country flag image URL from flagcdn.com
  String get countryFlagUrl {
    return CountryFlags.getFlagUrl(countryCode);
  }
  
  // Get country name from code
  String get countryName {
    return CountryFlags.getCountryName(countryCode);
  }
  
  // Check if this is a Smart Connect config
  bool get isSmartConnect => id == 'smart_connect';
  
  // Factory method to create Smart Connect config
  factory V2RayConfig.smartConnect() {
    return V2RayConfig(
      id: 'smart_connect',
      remark: 'smart_connect_display', // Translation key
      address: 'auto',
      port: 0,
      configType: 'smart',
      fullConfig: 'smart_connect',
      countryCode: null,
      isConnected: false,
    );
  }
  
  // Get display name for Smart Connect (with icon)
  String getDisplayName(String Function(String) translate) {
    if (isSmartConnect) {
      return '⚡ ${translate('server_selection.smart_connect')}';
    }
    return remark;
  }
  
  // Create a copy with updated fields
  V2RayConfig copyWith({
    String? id,
    String? remark,
    String? address,
    int? port,
    String? configType,
    String? fullConfig,
    String? countryCode,
    bool? isConnected,
  }) {
    return V2RayConfig(
      id: id ?? this.id,
      remark: remark ?? this.remark,
      address: address ?? this.address,
      port: port ?? this.port,
      configType: configType ?? this.configType,
      fullConfig: fullConfig ?? this.fullConfig,
      countryCode: countryCode ?? this.countryCode,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
