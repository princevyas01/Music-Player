import '../models/recommendation_model.dart';
import '../models/track_model.dart';
import 'recommendation_service.dart';

/// Produces optional future candidates only. Callers choose when to append
/// them through QueueService, which ensures an explicit queue is never silently
/// rewritten.
class AdaptiveQueueService {
  final RecommendationService _recommendations;

  AdaptiveQueueService(this._recommendations);

  List<Track> suggestions({
    required List<Track> library,
    required List<Track> currentQueue,
    required Track currentTrack,
    required bool enabled,
    required bool hasExplicitUpcomingQueue,
    int count = 5,
  }) {
    if (!enabled || hasExplicitUpcomingQueue || count <= 0) return const [];
    final queuedIds = currentQueue.map((track) => track.id).toSet();
    final candidates = _recommendations.recommend(
      library.where((track) => !queuedIds.contains(track.id)).toList(growable: false),
      mode: RecommendationMode.forYou,
      contextTrack: currentTrack,
      count: count * 3,
    );
    final selected = <Track>[];
    for (final track in candidates) {
      final previous = selected.isEmpty ? currentTrack : selected.last;
      if (track.id == previous.id || track.artist == previous.artist) continue;
      if (selected.any((item) => item.id == track.id)) continue;
      selected.add(track);
      if (selected.length == count) break;
    }
    return selected;
  }
}
