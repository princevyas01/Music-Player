import 'track_model.dart';

enum RecommendationMode {
  forYou,
  recentlyRelevant,
  rediscover,
  discover,
  deepCuts,
  forgottenFavorites,
  artistBased,
  albumBased,
  genreBased,
}

class RecommendationScore {
  final double recentAffinity;
  final double historicalAffinity;
  final double completionAffinity;
  final double artistAffinity;
  final double albumAffinity;
  final double genreAffinity;
  final double favoriteBoost;
  final double rediscoveryBoost;
  final double discoveryBoost;
  final double noveltyBoost;
  final double skipPenalty;
  final double recentRepeatPenalty;
  final double overplayPenalty;

  const RecommendationScore({
    this.recentAffinity = 0.0,
    this.historicalAffinity = 0.0,
    this.completionAffinity = 0.0,
    this.artistAffinity = 0.0,
    this.albumAffinity = 0.0,
    this.genreAffinity = 0.0,
    this.favoriteBoost = 0.0,
    this.rediscoveryBoost = 0.0,
    this.discoveryBoost = 0.0,
    this.noveltyBoost = 0.0,
    this.skipPenalty = 0.0,
    this.recentRepeatPenalty = 0.0,
    this.overplayPenalty = 0.0,
  });

  double get totalScore =>
      recentAffinity +
      historicalAffinity +
      completionAffinity +
      artistAffinity +
      albumAffinity +
      genreAffinity +
      favoriteBoost +
      rediscoveryBoost +
      discoveryBoost +
      noveltyBoost -
      skipPenalty -
      recentRepeatPenalty -
      overplayPenalty;
}

class ScoredTrack {
  final Track track;
  final RecommendationScore score;
  final String? reason;

  const ScoredTrack({
    required this.track,
    required this.score,
    this.reason,
  });
}
