import '../models/history_model.dart';
import '../models/recommendation_model.dart';
import '../models/track_model.dart';
import 'history_service.dart';
import 'storage_service.dart';

/// Deterministic local recommendation layer built above, not instead of,
/// SmartMixService. Every component is normalized to 0..1 before it is added.
class RecommendationService {
  final HistoryService _historyService;

  RecommendationService(this._historyService);

  List<ScoredTrack> rank(
    List<Track> tracks, {
    RecommendationMode mode = RecommendationMode.forYou,
    Track? contextTrack,
    int? limit,
  }) {
    if (tracks.isEmpty) return const [];
    final history = _historyService.historyMap;
    final favorites = StorageService.getFavoriteTrackIds();
    final now = DateTime.now();
    final maxPlayCount = _max(history.values.map((item) => item.playCount));
    final artistPlays = _groupPlays(tracks, history, (track) => track.artist);
    final albumPlays = _groupPlays(tracks, history, (track) => track.album);
    final genrePlays = _groupPlays(tracks, history, (track) => track.genre ?? '');
    final maxArtistPlays = _max(artistPlays.values);
    final maxAlbumPlays = _max(albumPlays.values);
    final maxGenrePlays = _max(genrePlays.values);

    final scored = <ScoredTrack>[];
    for (final track in tracks) {
      final item = history[track.id];
      final score = _score(
        track: track,
        history: item,
        favorites: favorites,
        now: now,
        maxPlayCount: maxPlayCount,
        artistAffinity: _ratio(artistPlays[track.artist] ?? 0, maxArtistPlays),
        albumAffinity: _ratio(albumPlays[track.album] ?? 0, maxAlbumPlays),
        genreAffinity: _ratio(genrePlays[track.genre ?? ''] ?? 0, maxGenrePlays),
        mode: mode,
        contextTrack: contextTrack,
      );
      if (_includeForMode(track, item, favorites, now, mode)) {
        scored.add(ScoredTrack(track: track, score: score, reason: _reasonFor(score, mode)));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.totalScore.compareTo(a.score.totalScore);
      if (byScore != 0) return byScore;
      final byId = a.track.id.compareTo(b.track.id);
      return byId != 0 ? byId : a.track.filePath.compareTo(b.track.filePath);
    });

    final diverse = _applyDiversity(scored);
    return limit == null ? diverse : diverse.take(limit).toList(growable: false);
  }

  List<Track> recommend(
    List<Track> tracks, {
    RecommendationMode mode = RecommendationMode.forYou,
    Track? contextTrack,
    int count = 25,
  }) => rank(tracks, mode: mode, contextTrack: contextTrack, limit: count)
      .map((item) => item.track)
      .toList(growable: false);

  RecommendationScore _score({
    required Track track,
    required PlaybackHistory? history,
    required Set<String> favorites,
    required DateTime now,
    required int maxPlayCount,
    required double artistAffinity,
    required double albumAffinity,
    required double genreAffinity,
    required RecommendationMode mode,
    required Track? contextTrack,
  }) {
    final playCount = history?.playCount ?? 0;
    final completed = history?.completedPlayCount ?? 0;
    final skips = history?.skipCount ?? 0;
    final daysSincePlayed = history == null
        ? 365.0
        : now.difference(history.lastPlayedAt).inHours / 24.0;
    final completionRate = _ratio(completed, playCount);
    final skipRate = _ratio(skips, playCount);
    final recentAffinity = history == null
        ? 0.0
        : 1.0 - (daysSincePlayed / 30.0).clamp(0.0, 1.0).toDouble();
    final historicalAffinity = _ratio(playCount, maxPlayCount);
    final isForgotten = history != null && daysSincePlayed >= 60;
    final isNew = now.difference(track.dateAdded).inDays <= 30;
    final isContextArtist = contextTrack != null && contextTrack.artist == track.artist;
    final isContextAlbum = contextTrack != null && contextTrack.album == track.album;
    final isContextGenre = contextTrack != null &&
        contextTrack.genre != null &&
        contextTrack.genre == track.genre;

    // Modes selectively expose the same components rather than a parallel
    // recommendation algorithm. Coefficients are documented profile choices:
    // 1 retains a signal, 0 removes it, and 2 deliberately foregrounds it.
    final profile = _profile(mode);
    return RecommendationScore(
      recentAffinity: recentAffinity * profile.recent,
      historicalAffinity: historicalAffinity * profile.historical,
      completionAffinity: completionRate * profile.completion,
      artistAffinity: (artistAffinity + (isContextArtist ? 1.0 : 0.0)) * profile.artist,
      albumAffinity: (albumAffinity + (isContextAlbum ? 1.0 : 0.0)) * profile.album,
      genreAffinity: (genreAffinity + (isContextGenre ? 1.0 : 0.0)) * profile.genre,
      favoriteBoost: (favorites.contains(track.id) ? 1.0 : 0.0) * profile.favorite,
      rediscoveryBoost: (isForgotten && skips <= completed ? 1.0 : 0.0) * profile.rediscovery,
      discoveryBoost: (history == null ? 1.0 : 0.0) * profile.discovery,
      noveltyBoost: (isNew ? 1.0 : 0.0) * profile.novelty,
      skipPenalty: skipRate * profile.skipPenalty,
      recentRepeatPenalty: (daysSincePlayed < 1 ? 1.0 : 0.0) * profile.recentRepeatPenalty,
      overplayPenalty: historicalAffinity * profile.overplayPenalty,
    );
  }

  bool _includeForMode(
    Track track,
    PlaybackHistory? history,
    Set<String> favorites,
    DateTime now,
    RecommendationMode mode,
  ) {
    final days = history == null ? null : now.difference(history.lastPlayedAt).inDays;
    switch (mode) {
      case RecommendationMode.discover:
        return history == null;
      case RecommendationMode.rediscover:
        return history != null && (days ?? 0) >= 30;
      case RecommendationMode.deepCuts:
        return (history?.playCount ?? 0) <= 3;
      case RecommendationMode.forgottenFavorites:
        return favorites.contains(track.id) && history != null && (days ?? 0) >= 30;
      default:
        return true;
    }
  }

  List<ScoredTrack> _applyDiversity(List<ScoredTrack> ranked) {
    final remaining = List<ScoredTrack>.from(ranked);
    final result = <ScoredTrack>[];
    String? lastArtist;
    String? lastAlbum;
    while (remaining.isNotEmpty) {
      final alternative = remaining.firstWhere(
        (item) => item.track.artist != lastArtist && item.track.album != lastAlbum,
        orElse: () => remaining.firstWhere(
          (item) => item.track.artist != lastArtist,
          orElse: () => remaining.first,
        ),
      );
      result.add(alternative);
      remaining.remove(alternative);
      lastArtist = alternative.track.artist;
      lastAlbum = alternative.track.album;
    }
    return result;
  }

  Map<String, int> _groupPlays(
    List<Track> tracks,
    Map<String, PlaybackHistory> history,
    String Function(Track track) keyOf,
  ) {
    final values = <String, int>{};
    for (final track in tracks) {
      final key = keyOf(track);
      values[key] = (values[key] ?? 0) + (history[track.id]?.playCount ?? 0);
    }
    return values;
  }

  int _max(Iterable<int> values) {
    var result = 0;
    for (final value in values) {
      if (value > result) result = value;
    }
    return result;
  }

  double _ratio(int value, int maximum) => maximum <= 0 ? 0.0 : value / maximum;

  String _reasonFor(RecommendationScore score, RecommendationMode mode) {
    if (mode == RecommendationMode.discover) return 'Unheard in your library';
    if (score.rediscoveryBoost > 0) return 'Worth rediscovering';
    if (score.favoriteBoost > 0) return 'A favorite you enjoy';
    if (score.artistAffinity > 0 || score.albumAffinity > 0) return 'Matches your listening';
    return 'Recommended from your library';
  }
}

class _RecommendationProfile {
  final double recent;
  final double historical;
  final double completion;
  final double artist;
  final double album;
  final double genre;
  final double favorite;
  final double rediscovery;
  final double discovery;
  final double novelty;
  final double skipPenalty;
  final double recentRepeatPenalty;
  final double overplayPenalty;

  const _RecommendationProfile({
    this.recent = 1,
    this.historical = 1,
    this.completion = 1,
    this.artist = 1,
    this.album = 1,
    this.genre = 1,
    this.favorite = 1,
    this.rediscovery = 1,
    this.discovery = 1,
    this.novelty = 1,
    this.skipPenalty = 1,
    this.recentRepeatPenalty = 1,
    this.overplayPenalty = 1,
  });
}

_RecommendationProfile _profile(RecommendationMode mode) {
  switch (mode) {
    case RecommendationMode.recentlyRelevant:
      return const _RecommendationProfile(historical: 0.5, recent: 2, novelty: 0.5);
    case RecommendationMode.rediscover:
      return const _RecommendationProfile(recent: 0, rediscovery: 2, overplayPenalty: 2);
    case RecommendationMode.discover:
      return const _RecommendationProfile(historical: 0, completion: 0, discovery: 2, novelty: 1.5);
    case RecommendationMode.deepCuts:
      return const _RecommendationProfile(historical: 0.25, discovery: 1.5, overplayPenalty: 2);
    case RecommendationMode.forgottenFavorites:
      return const _RecommendationProfile(recent: 0, favorite: 2, rediscovery: 2);
    case RecommendationMode.artistBased:
      return const _RecommendationProfile(artist: 2, album: 0.5);
    case RecommendationMode.albumBased:
      return const _RecommendationProfile(artist: 0.5, album: 2);
    case RecommendationMode.genreBased:
      return const _RecommendationProfile(artist: 0.5, genre: 2);
    case RecommendationMode.forYou:
      return const _RecommendationProfile();
  }
}
