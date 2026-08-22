import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/history_model.dart';
import '../models/track_model.dart';
import 'storage_service.dart';

class HistoryService extends ChangeNotifier {
  final Map<String, PlaybackHistory> _historyMap = {};
  Timer? _debounceTimer;

  HistoryService() {
    _loadHistory();
  }

  void _loadHistory() {
    _historyMap.clear();
    _historyMap.addAll(StorageService.getHistoryMap());
  }

  Map<String, PlaybackHistory> get historyMap => Map.unmodifiable(_historyMap);

  void recordTrackStart(String trackId) {
    final existing = _historyMap[trackId];
    final now = DateTime.now();
    if (existing == null) {
      _historyMap[trackId] = PlaybackHistory(
        trackId: trackId,
        playCount: 1,
        completedPlayCount: 0,
        lastPlayedAt: now,
        totalListenDurationMs: 0,
        lastPositionMs: 0,
      );
    } else {
      _historyMap[trackId] = existing.copyWith(
        playCount: existing.playCount + 1,
        lastPlayedAt: now,
      );
    }
    notifyListeners();
    _scheduleDebouncedSave();
  }

  void recordPlaybackProgress(String trackId, int positionMs, int deltaListenMs) {
    final existing = _historyMap[trackId];
    final now = DateTime.now();
    final todayKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final daily = Map<String, int>.from(existing?.dailyListenDurationMs ?? {});
    daily[todayKey] = (daily[todayKey] ?? 0) + deltaListenMs;

    // Prune entries older than 60 days to keep memory usage compact
    final cutoff = now.subtract(const Duration(days: 60));
    daily.removeWhere((key, _) {
      final dt = DateTime.tryParse(key);
      return dt != null && dt.isBefore(cutoff);
    });

    if (existing == null) {
      _historyMap[trackId] = PlaybackHistory(
        trackId: trackId,
        playCount: 1,
        lastPlayedAt: now,
        totalListenDurationMs: deltaListenMs,
        lastPositionMs: positionMs,
        dailyListenDurationMs: daily,
      );
    } else {
      _historyMap[trackId] = existing.copyWith(
        lastPlayedAt: now,
        lastPositionMs: positionMs,
        totalListenDurationMs: existing.totalListenDurationMs + deltaListenMs,
        dailyListenDurationMs: daily,
      );
    }
    notifyListeners();
    _scheduleDebouncedSave();
  }

  void recordTrackCompleted(String trackId) {
    final existing = _historyMap[trackId];
    final now = DateTime.now();
    if (existing != null) {
      _historyMap[trackId] = existing.copyWith(
        completedPlayCount: existing.completedPlayCount + 1,
        lastPlayedAt: now,
      );
      notifyListeners();
      _scheduleDebouncedSave();
    }
  }

  void recordTrackSkipped(String trackId) {
    final existing = _historyMap[trackId];
    if (existing != null) {
      _historyMap[trackId] = existing.copyWith(
        skipCount: existing.skipCount + 1,
      );
      notifyListeners();
      _scheduleDebouncedSave();
    }
  }

  List<Track> getRecentlyPlayedTracks(List<Track> allTracks, {int limit = 30}) {
    final map = Map<String, Track>.fromEntries(allTracks.map((t) => MapEntry(t.id, t)));
    final entries = _historyMap.values.where((h) => map.containsKey(h.trackId)).toList();
    entries.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    return entries.take(limit).map((h) => map[h.trackId]!).toList();
  }

  List<Track> getMostPlayedTracks(List<Track> allTracks, {int limit = 30}) {
    final map = Map<String, Track>.fromEntries(allTracks.map((t) => MapEntry(t.id, t)));
    final entries = _historyMap.values.where((h) => map.containsKey(h.trackId)).toList();
    entries.sort((a, b) => b.playCount.compareTo(a.playCount));
    return entries.take(limit).map((h) => map[h.trackId]!).toList();
  }

  List<String> getRecentlyPlayedArtists(List<Track> allTracks, {int limit = 10}) {
    final recentTracks = getRecentlyPlayedTracks(allTracks, limit: 100);
    final Set<String> artists = {};
    for (var track in recentTracks) {
      if (track.artist != 'Unknown Artist') {
        artists.add(track.artist);
        if (artists.length >= limit) break;
      }
    }
    return artists.toList();
  }

  List<String> getRecentlyPlayedAlbums(List<Track> allTracks, {int limit = 10}) {
    final recentTracks = getRecentlyPlayedTracks(allTracks, limit: 100);
    final Set<String> albums = {};
    for (var track in recentTracks) {
      if (track.album != 'Unknown Album') {
        albums.add(track.album);
        if (albums.length >= limit) break;
      }
    }
    return albums.toList();
  }

  void _scheduleDebouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 15), () {
      StorageService.saveAllHistory(_historyMap);
    });
  }

  void forceFlushSave() {
    _debounceTimer?.cancel();
    StorageService.saveAllHistory(_historyMap);
  }
}

