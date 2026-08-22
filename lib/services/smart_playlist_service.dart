import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track_model.dart';
import 'history_service.dart';
import 'storage_service.dart';

final smartPlaylistServiceProvider = Provider.family<SmartPlaylistService, HistoryService>((ref, historyService) {
  return SmartPlaylistService(historyService);
});

class SmartPlaylistService {
  final HistoryService _historyService;

  SmartPlaylistService(this._historyService);

  List<Track> getRecentlyAdded(List<Track> tracks, {int limit = 50}) {
    final sorted = List<Track>.from(tracks)..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return sorted.take(limit).toList();
  }

  List<Track> getRecentlyPlayed(List<Track> tracks, {int limit = 50}) {
    return _historyService.getRecentlyPlayedTracks(tracks, limit: limit);
  }

  List<Track> getMostPlayed(List<Track> tracks, {int limit = 50}) {
    return _historyService.getMostPlayedTracks(tracks, limit: limit);
  }

  List<Track> getFavorites(List<Track> tracks) {
    final favIds = StorageService.getFavoriteTrackIds();
    return tracks.where((t) => favIds.contains(t.id)).toList();
  }

  List<Track> getNeverPlayed(List<Track> tracks) {
    final history = _historyService.historyMap;
    return tracks.where((t) {
      final h = history[t.id];
      return h == null || h.playCount == 0;
    }).toList();
  }

  List<Track> getFrequentlyPlayed(List<Track> tracks, {int minPlays = 3}) {
    final history = _historyService.historyMap;
    return tracks.where((t) {
      final h = history[t.id];
      return h != null && h.playCount >= minPlays;
    }).toList();
  }

  List<Track> getForgottenSongs(List<Track> tracks, {int daysThreshold = 60}) {
    final history = _historyService.historyMap;
    final cutoff = DateTime.now().subtract(Duration(days: daysThreshold));

    return tracks.where((t) {
      final h = history[t.id];
      if (h == null) return false; // Never played is handled separately
      return h.lastPlayedAt.isBefore(cutoff) && h.skipCount < 3;
    }).toList();
  }

  List<Track> getShortTracks(List<Track> tracks, {int maxMs = 120000}) {
    return tracks.where((t) => t.durationMs > 0 && t.durationMs <= maxMs).toList();
  }

  List<Track> getLongTracks(List<Track> tracks, {int minMs = 300000}) {
    return tracks.where((t) => t.durationMs >= minMs).toList();
  }

  List<Track> getRecentlyCompleted(List<Track> tracks) {
    final history = _historyService.historyMap;
    final completed = tracks.where((t) {
      final h = history[t.id];
      return h != null && h.completedPlayCount > 0;
    }).toList();
    completed.sort((a, b) {
      final hA = history[a.id]!;
      final hB = history[b.id]!;
      return hB.lastPlayedAt.compareTo(hA.lastPlayedAt);
    });
    return completed;
  }
}
