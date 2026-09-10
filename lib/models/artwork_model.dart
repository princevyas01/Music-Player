import 'dart:typed_data';

enum ArtworkSource { embedded, mediaStore, cache, fallback }

class ArtworkModel {
  final String trackId;
  final Uint8List? bytes;
  final String? localFilePath;
  final String? uri;
  final ArtworkSource source;
  final DateTime cachedAt;

  const ArtworkModel({
    required this.trackId,
    this.bytes,
    this.localFilePath,
    this.uri,
    required this.source,
    required this.cachedAt,
  });

  bool get hasArtwork =>
      bytes != null ||
      (localFilePath != null && localFilePath!.isNotEmpty) ||
      (uri != null && uri!.isNotEmpty);

  ArtworkModel copyWith({
    Uint8List? bytes,
    String? localFilePath,
    String? uri,
    ArtworkSource? source,
    DateTime? cachedAt,
  }) {
    return ArtworkModel(
      trackId: trackId,
      bytes: bytes ?? this.bytes,
      localFilePath: localFilePath ?? this.localFilePath,
      uri: uri ?? this.uri,
      source: source ?? this.source,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  /// Byte payloads stay in the dedicated cache rather than normal settings or
  /// backup records. This map persists only a lightweight reusable reference.
  Map<String, dynamic> toMap() => {
        'trackId': trackId,
        'localFilePath': localFilePath,
        'uri': uri,
        'source': source.name,
        'cachedAt': cachedAt.toIso8601String(),
      };

  factory ArtworkModel.fromMap(Map<dynamic, dynamic> map) {
    return ArtworkModel(
      trackId: map['trackId'] as String,
      localFilePath: map['localFilePath'] as String?,
      uri: map['uri'] as String?,
      source: ArtworkSource.values.firstWhere(
        (value) => value.name == map['source'],
        orElse: () => ArtworkSource.cache,
      ),
      cachedAt: map['cachedAt'] != null
          ? DateTime.tryParse(map['cachedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
