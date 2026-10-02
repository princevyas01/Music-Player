import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

import '../models/artwork_model.dart';
import '../models/track_model.dart';
import 'audio_artwork_extractor.dart';
import 'smart_crop_service.dart';
import 'storage_service.dart';

/// Bounded, best-effort artwork resolver.
/// Resolves embedded, MediaStore, or companion photos for audio tracks,
/// running them through intelligent saliency cropping for circular vinyl discs.
class ArtworkService {
  final OnAudioQuery _audioQuery;
  final int maxMemoryEntries;
  final LinkedHashMap<String, ArtworkModel> _memory = LinkedHashMap();

  static final OnAudioQuery _staticAudioQuery = OnAudioQuery();
  static final Map<String, String> _resolvedPaths = {};
  static final Set<String> _inFlightResolutions = {};
  static String? _artworkDirPath;

  ArtworkService({OnAudioQuery? audioQuery, this.maxMemoryEntries = 100})
      : _audioQuery = audioQuery ?? OnAudioQuery();

  /// Gets the directory where artwork is cached
  static Future<String> getArtworkDirectoryPath() async {
    if (_artworkDirPath != null) return _artworkDirPath!;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _artworkDirPath = '${appDir.path}/custom_artwork';
      final dir = Directory(_artworkDirPath!);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (_) {
      _artworkDirPath = 'custom_artwork';
    }
    return _artworkDirPath!;
  }

  /// Sets or updates the cache for a track (e.g. after manual editing)
  static void setCachedArtworkPath(String trackId, String? path) {
    if (path == null || path.isEmpty) {
      _resolvedPaths.remove(trackId);
    } else {
      _resolvedPaths[trackId] = path;
    }
  }

  /// Synchronously returns cached artwork path if already resolved
  static String? getCachedArtworkPath(String trackId) {
    final cached = _resolvedPaths[trackId];
    if (cached != null) {
      return cached.isEmpty ? null : cached;
    }

    if (_artworkDirPath != null) {
      final safeId = trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final dir = Directory(_artworkDirPath!);
      if (dir.existsSync()) {
        try {
          final files = dir.listSync();
          // Priority 1: User-selected custom artwork ('art_')
          for (final f in files) {
            if (f is File) {
              final name = f.path.split(Platform.pathSeparator).last;
              if (name.startsWith('art_${safeId}_') || name == 'art_$safeId.jpg') {
                _resolvedPaths[trackId] = f.path;
                return f.path;
              }
            }
          }
          // Priority 2: Auto-selected audio artwork ('auto_')
          for (final f in files) {
            if (f is File) {
              final name = f.path.split(Platform.pathSeparator).last;
              if (name.startsWith('auto_${safeId}_') || name == 'auto_$safeId.jpg') {
                _resolvedPaths[trackId] = f.path;
                return f.path;
              }
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// Resolves the photo that came with the audio track (MediaStore / ID3 / APIC / covr / companion image),
  /// applies smart saliency circular crop, saves to disk, and caches the result.
  static Future<String?> resolveSmartArtwork({
    required String trackId,
    String? filePath,
    int? albumId,
    OnAudioQuery? audioQuery,
  }) async {
    if (_resolvedPaths.containsKey(trackId)) {
      final val = _resolvedPaths[trackId]!;
      return val.isEmpty ? null : val;
    }

    if (_inFlightResolutions.contains(trackId)) {
      await Future.delayed(const Duration(milliseconds: 100));
      return getCachedArtworkPath(trackId);
    }
    _inFlightResolutions.add(trackId);

    try {
      final outDir = await getArtworkDirectoryPath();
      final safeId = trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      // 1. Check disk for previously processed artwork
      final dir = Directory(outDir);
      if (dir.existsSync()) {
        final files = dir.listSync();
        for (final f in files) {
          if (f is File) {
            final name = f.path.split(Platform.pathSeparator).last;
            if (name.startsWith('art_${safeId}_') || name == 'art_$safeId.jpg') {
              _resolvedPaths[trackId] = f.path;
              return f.path;
            }
          }
        }
        for (final f in files) {
          if (f is File) {
            final name = f.path.split(Platform.pathSeparator).last;
            if (name.startsWith('auto_${safeId}_') || name == 'auto_$safeId.jpg') {
              _resolvedPaths[trackId] = f.path;
              return f.path;
            }
          }
        }
      }

      // 2. Extract raw photo bytes from the audio
      Uint8List? rawBytes;

      // Method A: query MediaStore on device via OnAudioQuery
      if (!kIsWeb) {
        final q = audioQuery ?? _staticAudioQuery;
        final mediaId = int.tryParse(trackId);
        if (mediaId != null) {
          try {
            final queryRes = await q.queryArtwork(
              mediaId,
              ArtworkType.AUDIO,
              quality: 100,
              format: ArtworkFormat.JPEG,
            );
            if (queryRes != null && queryRes.isNotEmpty) {
              rawBytes = Uint8List.fromList(queryRes);
            }
          } catch (_) {}
        }

        // Try album query if audio artwork was not found
        if (rawBytes == null && albumId != null && albumId > 0) {
          try {
            final albumRes = await q.queryArtwork(
              albumId,
              ArtworkType.ALBUM,
              quality: 100,
              format: ArtworkFormat.JPEG,
            );
            if (albumRes != null && albumRes.isNotEmpty) {
              rawBytes = Uint8List.fromList(albumRes);
            }
          } catch (_) {}
        }
      }

      // Method B: Direct embedded extraction from the audio file itself
      if (rawBytes == null && filePath != null && filePath.isNotEmpty) {
        rawBytes = await AudioArtworkExtractor.extractArtworkFromFile(filePath);
      }

      // 3. If photo found: Smart-crop it to square with saliency and circular weighting!
      if (rawBytes != null && rawBytes.isNotEmpty) {
        final savedPath = await SmartCropService.processAndSaveArtwork(
          imageBytes: rawBytes,
          trackId: trackId,
          outputDirectoryPath: outDir,
          prefix: 'auto_',
        );

        if (savedPath != null && savedPath.isNotEmpty) {
          _resolvedPaths[trackId] = savedPath;
          return savedPath;
        }
      }

      _resolvedPaths[trackId] = '';
      return null;
    } catch (e) {
      debugPrint('ArtworkService: resolveSmartArtwork error for $trackId: $e');
      return null;
    } finally {
      _inFlightResolutions.remove(trackId);
    }
  }

  /// Non-blocking background library pre-warmer
  static void warmupLibraryArtwork(List<Track> tracks) {
    if (kIsWeb || tracks.isEmpty) return;
    Future.microtask(() async {
      for (final track in tracks) {
        if (track.artworkUri == null || track.artworkUri!.isEmpty) {
          final cached = getCachedArtworkPath(track.id);
          if (cached == null) {
            await resolveSmartArtwork(
              trackId: track.id,
              filePath: track.filePath,
            );
            await Future.delayed(const Duration(milliseconds: 30));
          }
        }
      }
    });
  }

  Future<ArtworkModel> resolve(Track track) async {
    final inMemory = _memory[track.id];
    if (inMemory != null) return inMemory;
    try {
      if (track.artworkUri != null &&
          track.artworkUri!.isNotEmpty &&
          !track.artworkUri!.startsWith('content://')) {
        final f = File(track.artworkUri!);
        if (f.existsSync()) {
          return _remember(ArtworkModel(
            trackId: track.id,
            uri: track.artworkUri,
            localFilePath: track.artworkUri,
            source: ArtworkSource.embedded,
            cachedAt: DateTime.now(),
          ));
        }
      }

      final smartPath = await resolveSmartArtwork(
        trackId: track.id,
        filePath: track.filePath,
        audioQuery: _audioQuery,
      );

      if (smartPath != null && smartPath.isNotEmpty) {
        return _remember(ArtworkModel(
          trackId: track.id,
          localFilePath: smartPath,
          uri: smartPath,
          source: ArtworkSource.cache,
          cachedAt: DateTime.now(),
        ));
      }

      final persisted = StorageService.getCachedArtwork(track.id);
      if (persisted != null && persisted.hasArtwork) {
        return _remember(persisted);
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
    if (artwork.bytes == null) {
      StorageService.cacheArtwork(artwork);
    }
    return artwork;
  }
}
