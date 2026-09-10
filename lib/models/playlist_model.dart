class Playlist {
  final String id;
  final String name;
  final List<String> trackIds;
  final DateTime createdAt;
  final String? description;
  final String? coverArt;
  final DateTime? updatedAt;
  final String? sortMode;
  final String? folderId;
  final bool isSmart;
  final Map<String, dynamic>? smartRules;

  Playlist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
    this.description,
    this.coverArt,
    this.updatedAt,
    this.sortMode,
    this.folderId,
    this.isSmart = false,
    this.smartRules,
  });

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? trackIds,
    DateTime? createdAt,
    String? description,
    String? coverArt,
    DateTime? updatedAt,
    String? sortMode,
    String? folderId,
    bool clearFolder = false,
    bool? isSmart,
    Map<String, dynamic>? smartRules,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      coverArt: coverArt ?? this.coverArt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortMode: sortMode ?? this.sortMode,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      isSmart: isSmart ?? this.isSmart,
      smartRules: smartRules ?? this.smartRules,
    );
  }

  factory Playlist.fromMap(Map<dynamic, dynamic> map) {
    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      trackIds: List<String>.from(map['trackIds'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
      description: map['description'] as String?,
      coverArt: map['coverArt'] as String?,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
      sortMode: map['sortMode'] as String?,
      folderId: map['folderId'] as String?,
      isSmart: map['isSmart'] as bool? ?? false,
      smartRules: map['smartRules'] != null
          ? Map<String, dynamic>.from(map['smartRules'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'trackIds': trackIds,
      'createdAt': createdAt.toIso8601String(),
      if (description != null) 'description': description,
      if (coverArt != null) 'coverArt': coverArt,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (sortMode != null) 'sortMode': sortMode,
      if (folderId != null) 'folderId': folderId,
      'isSmart': isSmart,
      if (smartRules != null) 'smartRules': smartRules,
    };
  }
}
