/// Utility class for managing country flags and codes
/// Provides comprehensive list of all country codes and flag caching
class CountryFlags {
  // Complete list of ISO 3166-1 alpha-2 country codes
  static const Map<String, String> allCountryCodes = {
    // Africa
    'DZ': 'Algeria',
    'AO': 'Angola',
    'BJ': 'Benin',
    'BW': 'Botswana',
    'BF': 'Burkina Faso',
    'BI': 'Burundi',
    'CM': 'Cameroon',
    'CV': 'Cape Verde',
    'CF': 'Central African Republic',
    'TD': 'Chad',
    'KM': 'Comoros',
    'CG': 'Congo',
    'CD': 'Congo (DRC)',
    'CI': 'Ivory Coast',
    'DJ': 'Djibouti',
    'EG': 'Egypt',
    'GQ': 'Equatorial Guinea',
    'ER': 'Eritrea',
    'ET': 'Ethiopia',
    'GA': 'Gabon',
    'GM': 'Gambia',
    'GH': 'Ghana',
    'GN': 'Guinea',
    'GW': 'Guinea-Bissau',
    'KE': 'Kenya',
    'LS': 'Lesotho',
    'LR': 'Liberia',
    'LY': 'Libya',
    'MG': 'Madagascar',
    'MW': 'Malawi',
    'ML': 'Mali',
    'MR': 'Mauritania',
    'MU': 'Mauritius',
    'YT': 'Mayotte',
    'MA': 'Morocco',
    'MZ': 'Mozambique',
    'NA': 'Namibia',
    'NE': 'Niger',
    'NG': 'Nigeria',
    'RE': 'Reunion',
    'RW': 'Rwanda',
    'ST': 'Sao Tome and Principe',
    'SN': 'Senegal',
    'SC': 'Seychelles',
    'SL': 'Sierra Leone',
    'SO': 'Somalia',
    'ZA': 'South Africa',
    'SS': 'South Sudan',
    'SD': 'Sudan',
    'SZ': 'Swaziland',
    'TZ': 'Tanzania',
    'TG': 'Togo',
    'TN': 'Tunisia',
    'UG': 'Uganda',
    'ZM': 'Zambia',
    'ZW': 'Zimbabwe',
    
    // Americas
    'AI': 'Anguilla',
    'AG': 'Antigua and Barbuda',
    'AR': 'Argentina',
    'AW': 'Aruba',
    'BS': 'Bahamas',
    'BB': 'Barbados',
    'BZ': 'Belize',
    'BM': 'Bermuda',
    'BO': 'Bolivia',
    'BR': 'Brazil',
    'VG': 'British Virgin Islands',
    'CA': 'Canada',
    'KY': 'Cayman Islands',
    'CL': 'Chile',
    'CO': 'Colombia',
    'CR': 'Costa Rica',
    'CU': 'Cuba',
    'CW': 'Curacao',
    'DM': 'Dominica',
    'DO': 'Dominican Republic',
    'EC': 'Ecuador',
    'SV': 'El Salvador',
    'FK': 'Falkland Islands',
    'GF': 'French Guiana',
    'GL': 'Greenland',
    'GD': 'Grenada',
    'GP': 'Guadeloupe',
    'GT': 'Guatemala',
    'GY': 'Guyana',
    'HT': 'Haiti',
    'HN': 'Honduras',
    'JM': 'Jamaica',
    'MQ': 'Martinique',
    'MX': 'Mexico',
    'MS': 'Montserrat',
    'NI': 'Nicaragua',
    'PA': 'Panama',
    'PY': 'Paraguay',
    'PE': 'Peru',
    'PR': 'Puerto Rico',
    'BL': 'Saint Barthelemy',
    'KN': 'Saint Kitts and Nevis',
    'LC': 'Saint Lucia',
    'MF': 'Saint Martin',
    'PM': 'Saint Pierre and Miquelon',
    'VC': 'Saint Vincent and the Grenadines',
    'SR': 'Suriname',
    'TT': 'Trinidad and Tobago',
    'TC': 'Turks and Caicos Islands',
    'US': 'United States',
    'UY': 'Uruguay',
    'VE': 'Venezuela',
    'VI': 'Virgin Islands',
    
    // Asia
    'AF': 'Afghanistan',
    'AM': 'Armenia',
    'AZ': 'Azerbaijan',
    'BH': 'Bahrain',
    'BD': 'Bangladesh',
    'BT': 'Bhutan',
    'BN': 'Brunei',
    'KH': 'Cambodia',
    'CN': 'China',
    'GE': 'Georgia',
    'HK': 'Hong Kong',
    'IN': 'India',
    'ID': 'Indonesia',
    'IR': 'Iran',
    'IQ': 'Iraq',
    'IL': 'Israel',
    'JP': 'Japan',
    'JO': 'Jordan',
    'KZ': 'Kazakhstan',
    'KW': 'Kuwait',
    'KG': 'Kyrgyzstan',
    'LA': 'Laos',
    'LB': 'Lebanon',
    'MO': 'Macau',
    'MY': 'Malaysia',
    'MV': 'Maldives',
    'MN': 'Mongolia',
    'MM': 'Myanmar',
    'NP': 'Nepal',
    'KP': 'North Korea',
    'OM': 'Oman',
    'PK': 'Pakistan',
    'PS': 'Palestine',
    'PH': 'Philippines',
    'QA': 'Qatar',
    'SA': 'Saudi Arabia',
    'SG': 'Singapore',
    'KR': 'South Korea',
    'LK': 'Sri Lanka',
    'SY': 'Syria',
    'TW': 'Taiwan',
    'TJ': 'Tajikistan',
    'TH': 'Thailand',
    'TL': 'Timor-Leste',
    'TR': 'Turkey',
    'TM': 'Turkmenistan',
    'AE': 'UAE',
    'UZ': 'Uzbekistan',
    'VN': 'Vietnam',
    'YE': 'Yemen',
    
    // Europe
    'AX': 'Aland Islands',
    'AL': 'Albania',
    'AD': 'Andorra',
    'AT': 'Austria',
    'BY': 'Belarus',
    'BE': 'Belgium',
    'BA': 'Bosnia and Herzegovina',
    'BG': 'Bulgaria',
    'HR': 'Croatia',
    'CY': 'Cyprus',
    'CZ': 'Czech Republic',
    'DK': 'Denmark',
    'EE': 'Estonia',
    'FO': 'Faroe Islands',
    'FI': 'Finland',
    'FR': 'France',
    'DE': 'Germany',
    'GI': 'Gibraltar',
    'GR': 'Greece',
    'GG': 'Guernsey',
    'HU': 'Hungary',
    'IS': 'Iceland',
    'IE': 'Ireland',
    'IM': 'Isle of Man',
    'IT': 'Italy',
    'JE': 'Jersey',
    'XK': 'Kosovo',
    'LV': 'Latvia',
    'LI': 'Liechtenstein',
    'LT': 'Lithuania',
    'LU': 'Luxembourg',
    'MK': 'North Macedonia',
    'MT': 'Malta',
    'MD': 'Moldova',
    'MC': 'Monaco',
    'ME': 'Montenegro',
    'NL': 'Netherlands',
    'NO': 'Norway',
    'PL': 'Poland',
    'PT': 'Portugal',
    'RO': 'Romania',
    'RU': 'Russia',
    'SM': 'San Marino',
    'RS': 'Serbia',
    'SK': 'Slovakia',
    'SI': 'Slovenia',
    'ES': 'Spain',
    'SJ': 'Svalbard and Jan Mayen',
    'SE': 'Sweden',
    'CH': 'Switzerland',
    'UA': 'Ukraine',
    'GB': 'United Kingdom',
    'VA': 'Vatican City',
    
    // Oceania
    'AS': 'American Samoa',
    'AU': 'Australia',
    'CK': 'Cook Islands',
    'FJ': 'Fiji',
    'PF': 'French Polynesia',
    'GU': 'Guam',
    'KI': 'Kiribati',
    'MH': 'Marshall Islands',
    'FM': 'Micronesia',
    'NR': 'Nauru',
    'NC': 'New Caledonia',
    'NZ': 'New Zealand',
    'NU': 'Niue',
    'NF': 'Norfolk Island',
    'MP': 'Northern Mariana Islands',
    'PW': 'Palau',
    'PG': 'Papua New Guinea',
    'PN': 'Pitcairn Islands',
    'WS': 'Samoa',
    'SB': 'Solomon Islands',
    'TK': 'Tokelau',
    'TO': 'Tonga',
    'TV': 'Tuvalu',
    'VU': 'Vanuatu',
    'WF': 'Wallis and Futuna',
  };

  /// Check if a country code is valid
  static bool isValidCountryCode(String? code) {
    if (code == null || code.length != 2) return false;
    return allCountryCodes.containsKey(code.toUpperCase());
  }

  /// Get country name from code
  static String getCountryName(String? code) {
    if (code == null) return 'Unknown';
    return allCountryCodes[code.toUpperCase()] ?? code.toUpperCase();
  }

  /// Get flag URL for a country code
  static String getFlagUrl(String? code, {int width = 160}) {
    if (code == null || code.length != 2) {
      return 'https://flagcdn.com/w$width/un.png'; // UN flag as default
    }
    final validCode = code.toLowerCase();
    return 'https://flagcdn.com/w$width/$validCode.png';
  }

  /// Get flag emoji from country code
  static String getFlagEmoji(String? code) {
    if (code == null || code.length != 2) return '🌐';
    
    final upperCode = code.toUpperCase();
    // Convert country code to flag emoji
    // Each letter is converted to its regional indicator symbol
    return String.fromCharCodes(
      upperCode.codeUnits.map((c) => 0x1F1E6 + (c - 0x41))
    );
  }

  /// Extract country code from server remark/name
  static String? extractCountryCode(String remark) {
    final remarkUpper = remark.toUpperCase();
    
    // Try common patterns with brackets/parentheses first
    final bracketMatch = RegExp(r'[\[\(]([A-Z]{2})[\]\)]').firstMatch(remarkUpper);
    if (bracketMatch != null) {
      final code = bracketMatch.group(1)!;
      if (isValidCountryCode(code)) return code;
    }
    
    // Try patterns with separators: CC-, -CC-, CC|, |CC|
    final separatorMatch = RegExp(r'(?:^|[\s\-\|])([A-Z]{2})(?:[\s\-\|]|$)').firstMatch(remarkUpper);
    if (separatorMatch != null) {
      final code = separatorMatch.group(1)!;
      if (isValidCountryCode(code)) return code;
    }
    
    // Try to find any 2-letter uppercase code (last resort)
    final anyMatch = RegExp(r'\b([A-Z]{2})\b').firstMatch(remarkUpper);
    if (anyMatch != null) {
      final code = anyMatch.group(1)!;
      if (isValidCountryCode(code)) return code;
    }
    
    return null;
  }

  /// Get all country codes as a list
  static List<String> getAllCountryCodes() {
    return allCountryCodes.keys.toList()..sort();
  }

  /// Get all countries as a map (code -> name)
  static Map<String, String> getAllCountries() {
    return Map.from(allCountryCodes);
  }
}
