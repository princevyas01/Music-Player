import '../models/history_model.dart';
import '../models/track_model.dart';

class ListeningAnalytics {
  final int totalListenMs;
  final int weeklyListenMs;
  final int monthlyListenMs;
  final int listeningStreakDays;
  final double completionRate;
  final double skipRate;
  final Map<String, int> dailyListenMs;
  final Map<int, int> weekdayListenMs;
  final Map<String, int> artistListenMs;
  final Map<String, int> albumListenMs;
  final Map<String, int> genreListenMs;

  const ListeningAnalytics({
    required this.totalListenMs,
    required this.weeklyListenMs,
    required this.monthlyListenMs,
    required this.listeningStreakDays,
    required this.completionRate,
    required this.skipRate,
    required this.dailyListenMs,
    required this.weekdayListenMs,
    required this.artistListenMs,
    required this.albumListenMs,
    required this.genreListenMs,
  });
}

/// Memoized aggregation for analytics views. The cache key contains only
/// fields that affect the report and is invalidated naturally when history or
/// library metadata changes.
class AnalyticsReportService {
  String? _cacheKey;
  ListeningAnalytics? _cache;

  ListeningAnalytics compute(List<Track> tracks, Map<String, PlaybackHistory> history) {
    final cacheKey = _key(tracks, history);
    if (_cacheKey == cacheKey && _cache != null) return _cache!;

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    final trackById = {for (final track in tracks) track.id: track};
    final daily = <String, int>{};
    final weekday = <int, int>{};
    final artist = <String, int>{};
    final album = <String, int>{};
    final genre = <String, int>{};
    var total = 0;
    var weekly = 0;
    var monthly = 0;
    var plays = 0;
    var completions = 0;
    var skips = 0;

    for (final entry in history.entries) {
      final item = entry.value;
      total += item.totalListenDurationMs;
      plays += item.playCount;
      completions += item.completedPlayCount;
      skips += item.skipCount;
      final track = trackById[entry.key];
      if (track != null) {
        artist[track.artist] = (artist[track.artist] ?? 0) + item.totalListenDurationMs;
        album[track.album] = (album[track.album] ?? 0) + item.totalListenDurationMs;
        final genreKey = track.genre ?? 'Unknown Genre';
        genre[genreKey] = (genre[genreKey] ?? 0) + item.totalListenDurationMs;
      }
      for (final dayEntry in item.dailyListenDurationMs.entries) {
        daily[dayEntry.key] = (daily[dayEntry.key] ?? 0) + dayEntry.value;
        final date = DateTime.tryParse(dayEntry.key);
        if (date == null) continue;
        weekday[date.weekday] = (weekday[date.weekday] ?? 0) + dayEntry.value;
        final day = DateTime(date.year, date.month, date.day);
        if (!day.isBefore(weekStart)) weekly += dayEntry.value;
        if (!day.isBefore(monthStart)) monthly += dayEntry.value;
      }
    }

    _cacheKey = cacheKey;
    _cache = ListeningAnalytics(
      totalListenMs: total,
      weeklyListenMs: weekly,
      monthlyListenMs: monthly,
      listeningStreakDays: _streak(daily, now),
      completionRate: plays == 0 ? 0 : completions / plays,
      skipRate: plays == 0 ? 0 : skips / plays,
      dailyListenMs: Map.unmodifiable(daily),
      weekdayListenMs: Map.unmodifiable(weekday),
      artistListenMs: Map.unmodifiable(artist),
      albumListenMs: Map.unmodifiable(album),
      genreListenMs: Map.unmodifiable(genre),
    );
    return _cache!;
  }

  int _streak(Map<String, int> daily, DateTime now) {
    var streak = 0;
    var day = DateTime(now.year, now.month, now.day);
    while ((daily[_dayKey(day)] ?? 0) > 0) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  String _key(List<Track> tracks, Map<String, PlaybackHistory> history) {
    final trackKey = tracks.map((track) => '${track.id}:${track.artist}:${track.album}:${track.genre}').join('|');
    final historyKey = history.values
        .map((item) => '${item.trackId}:${item.playCount}:${item.completedPlayCount}:${item.skipCount}:${item.totalListenDurationMs}:${item.lastPlayedAt.microsecondsSinceEpoch}')
        .join('|');
    return '${_dayKey(DateTime.now())}#$trackKey#$historyKey';
  }
}
