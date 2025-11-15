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
    if (countryCode == null || countryCode!.length != 2) return '🌐';
    
    final code = countryCode!.toUpperCase();
    // Convert country code to flag emoji
    // Each letter is converted to its regional indicator symbol
    return String.fromCharCodes(
      code.codeUnits.map((c) => 0x1F1E6 + (c - 0x41))
    );
  }
  
  // Get country name from code
  String get countryName {
    if (countryCode == null) return 'Unknown';
    
    final countryNames = {
      // اروپا
      'DE': 'Germany',
      'FR': 'France',
      'GB': 'United Kingdom',
      'NL': 'Netherlands',
      'SE': 'Sweden',
      'FI': 'Finland',
      'PL': 'Poland',
      'IT': 'Italy',
      'ES': 'Spain',
      'CH': 'Switzerland',
      'AT': 'Austria',
      'BE': 'Belgium',
      'DK': 'Denmark',
      'NO': 'Norway',
      'IE': 'Ireland',
      'PT': 'Portugal',
      'GR': 'Greece',
      'CZ': 'Czech Republic',
      'RO': 'Romania',
      'HU': 'Hungary',
      'BG': 'Bulgaria',
      'SK': 'Slovakia',
      'HR': 'Croatia',
      'LT': 'Lithuania',
      'LV': 'Latvia',
      'EE': 'Estonia',
      'IS': 'Iceland',
      'LU': 'Luxembourg',
      'MT': 'Malta',
      'CY': 'Cyprus',
      'SI': 'Slovenia',
      'RS': 'Serbia',
      'UA': 'Ukraine',
      'MD': 'Moldova',
      'BY': 'Belarus',
      'BA': 'Bosnia',
      'MK': 'North Macedonia',
      'AL': 'Albania',
      'ME': 'Montenegro',
      
      // آمریکا
      'US': 'United States',
      'CA': 'Canada',
      'MX': 'Mexico',
      'BR': 'Brazil',
      'AR': 'Argentina',
      'CL': 'Chile',
      'CO': 'Colombia',
      'PE': 'Peru',
      'VE': 'Venezuela',
      'EC': 'Ecuador',
      'UY': 'Uruguay',
      'PY': 'Paraguay',
      'BO': 'Bolivia',
      'CR': 'Costa Rica',
      'PA': 'Panama',
      
      // آسیا
      'JP': 'Japan',
      'SG': 'Singapore',
      'HK': 'Hong Kong',
      'KR': 'South Korea',
      'TW': 'Taiwan',
      'IN': 'India',
      'CN': 'China',
      'TH': 'Thailand',
      'MY': 'Malaysia',
      'ID': 'Indonesia',
      'PH': 'Philippines',
      'VN': 'Vietnam',
      'KH': 'Cambodia',
      'LA': 'Laos',
      'MM': 'Myanmar',
      'BD': 'Bangladesh',
      'PK': 'Pakistan',
      'LK': 'Sri Lanka',
      'NP': 'Nepal',
      'MN': 'Mongolia',
      'KZ': 'Kazakhstan',
      'UZ': 'Uzbekistan',
      'KG': 'Kyrgyzstan',
      'TJ': 'Tajikistan',
      'TM': 'Turkmenistan',
      'AF': 'Afghanistan',
      
      // خاورمیانه
      'TR': 'Turkey',
      'AE': 'UAE',
      'SA': 'Saudi Arabia',
      'IL': 'Israel',
      'IQ': 'Iraq',
      'IR': 'Iran',
      'JO': 'Jordan',
      'LB': 'Lebanon',
      'SY': 'Syria',
      'YE': 'Yemen',
      'OM': 'Oman',
      'KW': 'Kuwait',
      'BH': 'Bahrain',
      'QA': 'Qatar',
      'PS': 'Palestine',
      'AM': 'Armenia',
      'AZ': 'Azerbaijan',
      'GE': 'Georgia',
      
      // اقیانوسیه
      'AU': 'Australia',
      'NZ': 'New Zealand',
      'FJ': 'Fiji',
      'PG': 'Papua New Guinea',
      
      // آفریقا
      'ZA': 'South Africa',
      'EG': 'Egypt',
      'NG': 'Nigeria',
      'KE': 'Kenya',
      'MA': 'Morocco',
      'TN': 'Tunisia',
      'DZ': 'Algeria',
      'LY': 'Libya',
      'SD': 'Sudan',
      'ET': 'Ethiopia',
      'GH': 'Ghana',
      'TZ': 'Tanzania',
      'UG': 'Uganda',
      'AO': 'Angola',
      'MZ': 'Mozambique',
      'ZW': 'Zimbabwe',
      'BW': 'Botswana',
      'NA': 'Namibia',
      'SN': 'Senegal',
      'CI': 'Ivory Coast',
      'CM': 'Cameroon',
      'RW': 'Rwanda',
    };
    
    return countryNames[countryCode!.toUpperCase()] ?? countryCode!.toUpperCase();
  }
}
