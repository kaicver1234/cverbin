class V2RayConfig {
  final String id;
  final String remark;
  final String address;
  final int port;
  final String configType; // vmess, vless, etc.
  final String fullConfig;
  bool isConnected;
  bool isProxyMode;

  V2RayConfig({
    required this.id,
    required this.remark,
    required this.address,
    required this.port,
    required this.configType,
    required this.fullConfig,
    this.isConnected = false,
    this.isProxyMode = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'remark': remark,
      'address': address,
      'port': port,
      'configType': configType,
      'fullConfig': fullConfig,
      'isConnected': isConnected,
      'isProxyMode': isProxyMode,
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
      isConnected: json['isConnected'] ?? false,
      isProxyMode: json['isProxyMode'] ?? false,
    );
  }
}
