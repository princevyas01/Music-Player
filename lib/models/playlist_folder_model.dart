class PlaylistFolder {
  final String id;
  final String name;
  final List<String> playlistIds;
  final DateTime createdAt;

  const PlaylistFolder({
    required this.id,
    required this.name,
    required this.playlistIds,
    required this.createdAt,
  });

  PlaylistFolder copyWith({
    String? id,
    String? name,
    List<String>? playlistIds,
    DateTime? createdAt,
  }) {
    return PlaylistFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      playlistIds: playlistIds ?? this.playlistIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'playlistIds': playlistIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PlaylistFolder.fromMap(Map<dynamic, dynamic> map) {
    return PlaylistFolder(
      id: map['id'] as String,
      name: map['name'] as String,
      playlistIds: List<String>.from(map['playlistIds'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
