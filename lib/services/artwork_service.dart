import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/artwork_model.dart';
import '../models/track_model.dart';
import 'storage_service.dart';

/// Bounded, best-effort artwork resolver. Artwork is secondary metadata: every
/// lookup is isolated so a MediaStore/device failure can never stop playback.
class ArtworkService {
  final OnAudioQuery _audioQuery;
  final int maxMemoryEntries;
  final LinkedHashMap<String, ArtworkModel> _memory = LinkedHashMap();

  ArtworkService({OnAudioQuery? audioQuery, this.maxMemoryEntries = 100})
      : _audioQuery = audioQuery ?? OnAudioQuery();

  Future<ArtworkModel> resolve(Track track) async {
    final inMemory = _memory[track.id];
    if (inMemory != null) return inMemory;
    try {
      // Track metadata can already carry an embedded or MediaStore URI.
      if (track.artworkUri != null && track.artworkUri!.isNotEmpty) {
        return _remember(ArtworkModel(
          trackId: track.id,
          uri: track.artworkUri,
          source: track.artworkUri!.startsWith('content://')
              ? ArtworkSource.mediaStore
              : ArtworkSource.embedded,
          cachedAt: DateTime.now(),
        ));
      }

      final persisted = StorageService.getCachedArtwork(track.id);
      if (persisted != null && persisted.hasArtwork) {
        return _remember(persisted);
      }

      final mediaId = int.tryParse(track.id);
      if (!kIsWeb && mediaId != null) {
        final bytes = await _audioQuery.queryArtwork(mediaId, ArtworkType.AUDIO);
        if (bytes != null && bytes.isNotEmpty) {
          return _remember(ArtworkModel(
            trackId: track.id,
            bytes: Uint8List.fromList(bytes),
            source: ArtworkSource.mediaStore,
            cachedAt: DateTime.now(),
          ));
        }
      }
    } catch (error) {
      debugPrint('ArtworkService: unable to resolve ${track.id}: $error');
    }
    return _remember(ArtworkModel(
      trackId: track.id,
      source: ArtworkSource.fallback,
      cachedAt: DateTime.now(),
    ));
  }

  ArtworkModel _remember(ArtworkModel artwork) {
    _memory.remove(artwork.trackId);
    _memory[artwork.trackId] = artwork;
    while (_memory.length > maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
    // Store only references; MediaStore bytes remain memory-cached and bounded.
    if (artwork.bytes == null) {
      StorageService.cacheArtwork(artwork);
    }
    return artwork;
  }
}
