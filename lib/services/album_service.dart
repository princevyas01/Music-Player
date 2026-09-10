import '../models/history_model.dart';
import '../models/track_model.dart';

class AlbumProfile {
  final String name;
  final String artist;
  final int? year;
  final List<Track> tracks;
  final int totalDurationMs;
  final int playCount;
  final DateTime? lastPlayedAt;
  final double completionRate;

  const AlbumProfile({
    required this.name,
    required this.artist,
    required this.year,
    required this.tracks,
    required this.totalDurationMs,
    required this.playCount,
    required this.lastPlayedAt,
    required this.completionRate,
  });
}

class AlbumService {
  const AlbumService();

  AlbumProfile? buildProfile(
    String album,
    String artist,
    List<Track> library,
    Map<String, PlaybackHistory> history,
  ) {
    final tracks = library
        .where((track) => track.album == album && track.artist == artist)
        .toList();
    if (tracks.isEmpty) return null;
    tracks.sort((a, b) {
      final disc = (a.discNumber ?? 0).compareTo(b.discNumber ?? 0);
      if (disc != 0) return disc;
      final number = (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
      return number != 0 ? number : a.title.compareTo(b.title);
    });
    var duration = 0;
    var plays = 0;
    var completions = 0;
    DateTime? lastPlayed;
    for (final track in tracks) {
      duration += track.durationMs;
      final item = history[track.id];
      plays += item?.playCount ?? 0;
      completions += item?.completedPlayCount ?? 0;
      if (item != null && (lastPlayed == null || item.lastPlayedAt.isAfter(lastPlayed))) {
        lastPlayed = item.lastPlayedAt;
      }
    }
    return AlbumProfile(
      name: album,
      artist: artist,
      year: tracks.map((track) => track.year).whereType<int>().fold<int?>(null, (value, year) => value == null || year < value ? year : value),
      tracks: tracks,
      totalDurationMs: duration,
      playCount: plays,
      lastPlayedAt: lastPlayed,
      completionRate: plays == 0 ? 0 : completions / plays,
    );
  }
}
