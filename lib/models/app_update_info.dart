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

  // Compare version strings (e.g., "1.0.1" vs "1.0.0").
  //
  // Handles versions with different component counts ("1.2" vs "1.2.0" are
  // equal, not an update) and build/pre-release suffixes ("1.2.0+build3",
  // "1.2.0-beta") by reading only the leading numeric part of each segment.
  bool isNewerThan(String currentVersion) {
    int parseSegment(String s) =>
        int.tryParse(s.split(RegExp(r'[-+]')).first.trim()) ?? 0;

    final current = currentVersion.split('.').map(parseSegment).toList();
    final update = version.split('.').map(parseSegment).toList();

    final maxLen = update.length > current.length ? update.length : current.length;
    for (int i = 0; i < maxLen; i++) {
      // Treat a missing component as 0 so "1.2" and "1.2.0" compare equal.
      final u = i < update.length ? update[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (u > c) return true;
      if (u < c) return false;
    }
    return false;
  }
}
