class AppUpdateInfo {
  final String version;
  final String title;
  final String message;
  final String downloadUrl;
  final bool isForced;

  AppUpdateInfo({
    required this.version,
    required this.title,
    required this.message,
    required this.downloadUrl,
    required this.isForced,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: json['version'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
      isForced: json['isForced'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'title': title,
      'message': message,
      'downloadUrl': downloadUrl,
      'isForced': isForced,
    };
  }

  // Compare version strings (e.g., "1.0.1" vs "1.0.0")
  bool isNewerThan(String currentVersion) {
    try {
      final current = currentVersion.split('.').map(int.parse).toList();
      final update = version.split('.').map(int.parse).toList();
      
      for (int i = 0; i < update.length && i < current.length; i++) {
        if (update[i] > current[i]) return true;
        if (update[i] < current[i]) return false;
      }
      
      return update.length > current.length;
    } catch (e) {
      return false;
    }
  }
}
