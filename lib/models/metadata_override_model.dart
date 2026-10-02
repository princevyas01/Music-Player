class MetadataOverride {
  final String trackId;
  final String? title;
  final String? artist;
  final String? album;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final String? artworkUri;
  final DateTime updatedAt;

  MetadataOverride({
    required this.trackId,
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.artworkUri,
    required this.updatedAt,
  });

  MetadataOverride copyWith({
    String? trackId,
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    String? artworkUri,
    bool clearArtwork = false,
    DateTime? updatedAt,
  }) {
    return MetadataOverride(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      artworkUri: clearArtwork ? '' : (artworkUri ?? this.artworkUri),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'year': year,
      'trackNumber': trackNumber,
      'discNumber': discNumber,
      'artworkUri': artworkUri,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MetadataOverride.fromMap(Map<dynamic, dynamic> map) {
    return MetadataOverride(
      trackId: map['trackId'] as String,
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      genre: map['genre'] as String?,
      year: (map['year'] as num?)?.toInt(),
      trackNumber: (map['trackNumber'] as num?)?.toInt(),
      discNumber: (map['discNumber'] as num?)?.toInt(),
      artworkUri: map['artworkUri'] as String?,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
