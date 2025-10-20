import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../models/app_update_info.dart';

class UpdateCheckerService {
  // Add timestamp to bypass cache
  static String get _updateUrl => 
      'https://gist.githubusercontent.com/cverhud/41d9dbbc00a9320853b2d880c9184e5f/raw/tiksar-vpn.json?t=${DateTime.now().millisecondsSinceEpoch}';

  // Check for updates - called every time app opens
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      // Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // Fetch update info from GitHub Gist (with no-cache headers and timestamp)
      final response = await http.get(
        Uri.parse(_updateUrl),
        headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final AppUpdateInfo updateInfo = AppUpdateInfo.fromJson(json);

        // Check if update is newer than current version
        if (updateInfo.isNewerThan(currentVersion)) {
          // Always show update if version is newer, regardless of dismiss status
          return updateInfo;
        }
      }
    } catch (e) {
      // Error checking for update
    }

    return null;
  }
}
