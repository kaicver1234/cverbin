class Subscription {
  final String id;
  final String name;
  final String url;
  final DateTime lastUpdated;
  final List<String> configIds; // IDs of V2RayConfig objects
  final bool isUserAdded; // False for the built-in default subscription

  Subscription({
    required this.id,
    required this.name,
    required this.url,
    required this.lastUpdated,
    required this.configIds,
    this.isUserAdded = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'lastUpdated': lastUpdated.toIso8601String(),
      'configIds': configIds,
      'isUserAdded': isUserAdded,
    };
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
      configIds: List<String>.from(json['configIds']),
      isUserAdded: json['isUserAdded'] ?? false,
    );
  }

  Subscription copyWith({
    String? id,
    String? name,
    String? url,
    DateTime? lastUpdated,
    List<String>? configIds,
    bool? isUserAdded,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      configIds: configIds ?? this.configIds,
      isUserAdded: isUserAdded ?? this.isUserAdded,
    );
  }
}
