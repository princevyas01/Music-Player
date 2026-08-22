import '../models/track_model.dart';
import 'history_service.dart';

class MusicStatsData {
  final int totalTracks;
  final int totalAlbums;
  final int totalArtists;
  final int totalListenTimeMs;
  final List<Track> topTracks;
  final List<String> topArtists;
  final List<String> topAlbums;
  final int weeklyListenTimeMs;
  final int monthlyListenTimeMs;

  MusicStatsData({
    required this.totalTracks,
    required this.totalAlbums,
    required this.totalArtists,
    required this.totalListenTimeMs,
    required this.topTracks,
    required this.topArtists,
    required this.topAlbums,
    required this.weeklyListenTimeMs,
    required this.monthlyListenTimeMs,
  });

  String formatDuration(int durationMs) {
    final duration = Duration(milliseconds: durationMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class MusicStatsService {
  final HistoryService _historyService;

  MusicStatsService(this._historyService);

  MusicStatsData computeStats(List<Track> tracks) {
    final history = _historyService.historyMap;

    final Set<String> albums = {};
    final Set<String> artists = {};
    for (var track in tracks) {
      if (track.album != 'Unknown Album') albums.add(track.album);
      if (track.artist != 'Unknown Artist') artists.add(track.artist);
    }

    int totalListenTimeMs = 0;
    int weeklyListenTimeMs = 0;
    int monthlyListenTimeMs = 0;

    final now = DateTime.now();
    final weekCutoff = now.subtract(const Duration(days: 7));
    final monthCutoff = now.subtract(const Duration(days: 30));

    final Map<String, int> artistPlayCounts = {};
    final Map<String, int> albumPlayCounts = {};

    final Map<String, Track> trackMap = {for (var t in tracks) t.id: t};

    final todayStart = DateTime(now.year, now.month, now.day);
    final weekCutoffStart = todayStart.subtract(const Duration(days: 7));
    final monthCutoffStart = todayStart.subtract(const Duration(days: 30));

    for (var entry in history.entries) {
      final h = entry.value;
      totalListenTimeMs += h.totalListenDurationMs;

      if (h.dailyListenDurationMs.isNotEmpty) {
        h.dailyListenDurationMs.forEach((dateStr, durMs) {
          final dt = DateTime.tryParse(dateStr);
          if (dt != null) {
            final dayDate = DateTime(dt.year, dt.month, dt.day);
            if (!dayDate.isBefore(weekCutoffStart)) {
              weeklyListenTimeMs += durMs;
            }
            if (!dayDate.isBefore(monthCutoffStart)) {
              monthlyListenTimeMs += durMs;
            }
          }
        });
      } else {
        // Fallback for legacy history items before daily tracking
        if (h.lastPlayedAt.isAfter(weekCutoff)) {
          weeklyListenTimeMs += h.totalListenDurationMs;
        }
        if (h.lastPlayedAt.isAfter(monthCutoff)) {
          monthlyListenTimeMs += h.totalListenDurationMs;
        }
      }

      final track = trackMap[h.trackId];
      if (track != null) {
        if (track.artist != 'Unknown Artist') {
          artistPlayCounts[track.artist] = (artistPlayCounts[track.artist] ?? 0) + h.playCount;
        }
        if (track.album != 'Unknown Album') {
          albumPlayCounts[track.album] = (albumPlayCounts[track.album] ?? 0) + h.playCount;
        }
      }
    }

    final topTracks = _historyService.getMostPlayedTracks(tracks, limit: 5);

    final sortedArtists = artistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topArtists = sortedArtists.take(5).map((e) => e.key).toList();

    final sortedAlbums = albumPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topAlbums = sortedAlbums.take(5).map((e) => e.key).toList();

    return MusicStatsData(
      totalTracks: tracks.length,
      totalAlbums: albums.length,
      totalArtists: artists.length,
      totalListenTimeMs: totalListenTimeMs,
      topTracks: topTracks,
      topArtists: topArtists,
      topAlbums: topAlbums,
      weeklyListenTimeMs: weeklyListenTimeMs,
      monthlyListenTimeMs: monthlyListenTimeMs,
    );
  }
}
