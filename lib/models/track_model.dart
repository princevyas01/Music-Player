class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String filePath;
  final String? artworkUri;
  final DateTime dateAdded;
  final String? genre;
  final int? year;
  final String? albumArtist;
  final int? trackNumber;
  final int? discNumber;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.filePath,
    this.artworkUri,
    required this.dateAdded,
    this.genre,
    this.year,
    this.albumArtist,
    this.trackNumber,
    this.discNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': durationMs,
      'filePath': filePath,
      'artworkUri': artworkUri,
      'dateAdded': dateAdded.toIso8601String(),
      'genre': genre,
      'year': year,
      'albumArtist': albumArtist,
      'trackNumber': trackNumber,
      'discNumber': discNumber,
    };
  }

  factory Track.fromMap(Map<dynamic, dynamic> map) {
    return Track(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Unknown Title',
      artist: map['artist'] as String? ?? 'Unknown Artist',
      album: map['album'] as String? ?? 'Unknown Album',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      filePath: map['filePath'] as String? ?? '',
      artworkUri: map['artworkUri'] as String?,
      dateAdded: map['dateAdded'] != null
          ? DateTime.tryParse(map['dateAdded'] as String) ?? DateTime.now()
          : DateTime.now(),
      genre: map['genre'] as String?,
      year: (map['year'] as num?)?.toInt(),
      albumArtist: map['albumArtist'] as String?,
      trackNumber: (map['trackNumber'] as num?)?.toInt(),
      discNumber: (map['discNumber'] as num?)?.toInt(),
    );
  }

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? filePath,
    String? artworkUri,
    DateTime? dateAdded,
    String? genre,
    int? year,
    String? albumArtist,
    int? trackNumber,
    int? discNumber,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      filePath: filePath ?? this.filePath,
      artworkUri: artworkUri ?? this.artworkUri,
      dateAdded: dateAdded ?? this.dateAdded,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      albumArtist: albumArtist ?? this.albumArtist,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Track &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          filePath == other.filePath;

  @override
  int get hashCode => id.hashCode ^ filePath.hashCode;
}
