import 'dart:async';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import '../models/track_model.dart';
import 'storage_service.dart';

class LibraryService {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  bool _notificationPermissionRequested = false;

  /// Request audio/storage permission for library scanning
  Future<bool> requestAudioPermission() async {
    if (kIsWeb) return true;

    var audioStatus = await Permission.audio.status;
    if (audioStatus.isGranted) return true;

    audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    var storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.storage.request();
    }
    return storageStatus.isGranted;
  }

  /// Request notification permission once for Android 13+
  Future<void> requestNotificationPermission() async {
    if (kIsWeb || _notificationPermissionRequested) return;
    _notificationPermissionRequested = true;

    var notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<List<Track>> queryDeviceTracks({bool forceRescan = false}) async {
    try {
      final bool hasPermission = await requestAudioPermission();
      unawaited(requestNotificationPermission());

      if (!hasPermission && !kIsWeb) {
        debugPrint('LibraryService: Storage permission denied. Returning cached tracks.');
        return StorageService.getSavedTracks();
      }

      if (!forceRescan) {
        final cached = StorageService.getSavedTracks();
        if (cached.isNotEmpty) return cached;
      }

      final songModels = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      if (songModels.isEmpty) {
        debugPrint('LibraryService: No device tracks found in MediaStore.');
        final cached = StorageService.getSavedTracks();
        return cached;
      }

      final minMs = StorageService.getShortTrackThresholdSeconds() * 1000;

      final List<Track> tracks = songModels
          .where((song) => (song.duration ?? 0) >= minMs)
          .map((song) {
        int timestamp = song.dateAdded ?? 0;
        if (timestamp == 0) timestamp = song.dateModified ?? 0;

        final dateAddedMs = (timestamp > 0)
            ? (timestamp > 10000000000 ? timestamp : timestamp * 1000)
            : DateTime.now().millisecondsSinceEpoch;

        final rawTitle = song.title;
        final title = rawTitle.trim().isNotEmpty ? rawTitle.trim() : 'Unknown Track';

        final genre = song.genre != null && song.genre != '<unknown>' ? song.genre!.trim() : null;

        return Track(
          id: song.id.toString(),
          title: title,
          artist: (song.artist != null && song.artist != '<unknown>')
              ? song.artist!.trim()
              : 'Unknown Artist',
          album: (song.album != null && song.album != '<unknown>')
              ? song.album!.trim()
              : 'Unknown Album',
          durationMs: song.duration ?? 180000,
          filePath: song.uri ?? song.data,
          artworkUri: null,
          dateAdded: DateTime.fromMillisecondsSinceEpoch(dateAddedMs),
          genre: genre,
          year: song.getMap['year'] != null ? int.tryParse(song.getMap['year'].toString()) : null,
          trackNumber: song.getMap['track'] != null ? int.tryParse(song.getMap['track'].toString()) : null,
        );
      }).toList();

      tracks.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));

      // Safe cache replacement strictly on verified query completion
      if (forceRescan) {
        await StorageService.clearTracks();
      }
      await StorageService.saveTracks(tracks);
      return tracks;
    } catch (e) {
      debugPrint('LibraryService query error: $e');
      return StorageService.getSavedTracks();
    }
  }
}
