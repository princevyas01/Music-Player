class Favorite {
  final String trackId;
  final DateTime addedAt;

  Favorite({
    required this.trackId,
    required this.addedAt,
  });

  factory Favorite.fromMap(Map<dynamic, dynamic> map) {
    return Favorite(
      trackId: map['trackId'] as String,
      addedAt: DateTime.parse(map['addedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}
