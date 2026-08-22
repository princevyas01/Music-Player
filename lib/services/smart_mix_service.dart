import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track_model.dart';
import 'history_service.dart';
import 'storage_service.dart';

final smartMixServiceProvider = Provider.family<SmartMixService, HistoryService>((ref, historyService) {
  return SmartMixService(historyService);
});

class SmartMixService {
  final HistoryService _historyService;

  SmartMixService(this._historyService);

  List<Track> generateMix(List<Track> allTracks, {int count = 25}) {
    if (allTracks.isEmpty) return [];

    final favIds = StorageService.getFavoriteTrackIds();
    final history = _historyService.historyMap;

    final now = DateTime.now();
    final recentCutoff = now.subtract(const Duration(hours: 24));
    final forgottenCutoff = now.subtract(const Duration(days: 60));

    final Map<Track, double> scores = {};

    for (final track in allTracks) {
      double score = 10.0;

      // 1. Favorites boost
      if (favIds.contains(track.id)) score += 30.0;

      final h = history[track.id];
      if (h != null) {
        // 2. Play count weight
        score += min(h.playCount * 2.0, 20.0);

        // 3. Recently played penalty
        if (h.lastPlayedAt.isAfter(recentCutoff)) {
          score -= 25.0;
        }

        // 4. Forgotten song boost
        if (h.lastPlayedAt.isBefore(forgottenCutoff) && h.skipCount < 3) {
          score += 18.0;
        }

        // 5. High skip penalty
        if (h.skipCount > h.playCount) {
          score -= 15.0;
        }
      } else {
        // Never played slight discovery bonus
        score += 8.0;
      }

      // 6. Recently added bonus
      final daysOld = now.difference(track.dateAdded).inDays;
      if (daysOld <= 14) {
        score += 15.0;
      }

      scores[track] = max(score, 1.0);
    }

    // Weighted random selection with artist diversity guard
    final List<Track> mix = [];
    final List<Track> pool = List.from(allTracks);
    final Random rng = Random(DateTime.now().millisecondsSinceEpoch);

    String? lastArtist;

    while (mix.length < count && pool.isNotEmpty) {
      final double totalScore = pool.fold(0.0, (sum, t) => sum + (scores[t] ?? 1.0));
      double randVal = rng.nextDouble() * totalScore;

      Track? selected;
      for (final track in pool) {
        randVal -= (scores[track] ?? 1.0);
        if (randVal <= 0) {
          selected = track;
          break;
        }
      }
      selected ??= pool.first;

      // Artist diversity check
      if (lastArtist != null && selected.artist == lastArtist && pool.length > 3) {
        // Find alternative candidate
        final alt = pool.firstWhere((t) => t.artist != lastArtist, orElse: () => selected!);
        selected = alt;
      }

      mix.add(selected);
      lastArtist = selected.artist;
      pool.remove(selected);
    }

    return mix;
  }
}
