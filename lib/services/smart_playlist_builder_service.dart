import '../models/history_model.dart';
import '../models/playlist_model.dart';
import '../models/smart_playlist_rule_model.dart';
import '../models/track_model.dart';

/// Rule evaluator for user-created smart playlists. Definitions are persisted
/// separately and evaluated against current library/history data on demand, so
/// no duplicated static track lists can become stale.
class SmartPlaylistBuilderService {
  const SmartPlaylistBuilderService();

  List<Track> evaluate({
    required SmartPlaylistDefinition definition,
    required List<Track> tracks,
    required Map<String, PlaybackHistory> history,
    required Set<String> favoriteTrackIds,
    required List<Playlist> playlists,
  }) {
    final playlistMembership = <String, Set<String>>{};
    for (final playlist in playlists) {
      for (final trackId in playlist.trackIds) {
        playlistMembership.putIfAbsent(trackId, () => <String>{}).add(playlist.id);
        playlistMembership.putIfAbsent(trackId, () => <String>{}).add(playlist.name);
      }
    }
    final now = DateTime.now();
    final unique = <String, Track>{};
    for (final track in tracks) {
      final results = definition.rules.map((rule) => _matches(
        rule: rule,
        track: track,
        history: history[track.id],
        favoriteTrackIds: favoriteTrackIds,
        memberships: playlistMembership[track.id] ?? const <String>{},
        now: now,
      ));
      final matches = definition.rules.isEmpty
          ? true
          : definition.matchAll
              ? results.every((result) => result)
              : results.any((result) => result);
      if (matches) unique.putIfAbsent(track.id, () => track);
    }
    final result = unique.values.toList(growable: false);
    return _sort(result, definition.sortOption, history, definition.limit);
  }

  bool _matches({
    required SmartRule rule,
    required Track track,
    required PlaybackHistory? history,
    required Set<String> favoriteTrackIds,
    required Set<String> memberships,
    required DateTime now,
  }) {
    final value = rule.value;
    switch (rule.field) {
      case SmartRuleField.artist:
        return _text(track.artist, rule.operator, value);
      case SmartRuleField.album:
        return _text(track.album, rule.operator, value);
      case SmartRuleField.genre:
        return _text(track.genre ?? '', rule.operator, value);
      case SmartRuleField.year:
        return _number(track.year ?? 0, rule.operator, value);
      case SmartRuleField.duration:
        return _number(track.durationMs ~/ 1000, rule.operator, value);
      case SmartRuleField.dateAdded:
        return _date(track.dateAdded, rule.operator, value);
      case SmartRuleField.lastPlayed:
        return _date(history?.lastPlayedAt, rule.operator, value);
      case SmartRuleField.playCount:
        return _number(history?.playCount ?? 0, rule.operator, value);
      case SmartRuleField.skipCount:
        return _number(history?.skipCount ?? 0, rule.operator, value);
      case SmartRuleField.completionCount:
        return _number(history?.completedPlayCount ?? 0, rule.operator, value);
      case SmartRuleField.neverPlayed:
        return _boolean(history == null || history.playCount == 0, rule.operator, value);
      case SmartRuleField.recentlyPlayed:
        final days = _numberValue(value) ?? 30;
        return _boolean(
          history != null && now.difference(history.lastPlayedAt).inDays <= days,
          rule.operator,
          value,
        );
      case SmartRuleField.recentlyAdded:
        final days = _numberValue(value) ?? 30;
        return _boolean(now.difference(track.dateAdded).inDays <= days, rule.operator, value);
      case SmartRuleField.favorites:
        return _boolean(favoriteTrackIds.contains(track.id), rule.operator, value);
      case SmartRuleField.playlistMembership:
        return memberships.any((membership) => _text(membership, rule.operator, value));
    }
  }

  bool _text(String source, SmartRuleOperator operator, dynamic value) {
    final target = value?.toString().trim().toLowerCase() ?? '';
    final normalized = source.trim().toLowerCase();
    switch (operator) {
      case SmartRuleOperator.equals:
        return normalized == target;
      case SmartRuleOperator.contains:
        return normalized.contains(target);
      default:
        return false;
    }
  }

  bool _number(int source, SmartRuleOperator operator, dynamic value) {
    final target = _numberValue(value);
    if (target == null) return false;
    switch (operator) {
      case SmartRuleOperator.equals:
        return source == target;
      case SmartRuleOperator.greaterThan:
        return source > target;
      case SmartRuleOperator.lessThan:
        return source < target;
      default:
        return false;
    }
  }

  bool _date(DateTime? source, SmartRuleOperator operator, dynamic value) {
    if (source == null) return false;
    final target = value is DateTime ? value : DateTime.tryParse(value?.toString() ?? '');
    if (target == null) return false;
    switch (operator) {
      case SmartRuleOperator.equals:
        return source.year == target.year && source.month == target.month && source.day == target.day;
      case SmartRuleOperator.greaterThan:
        return source.isAfter(target);
      case SmartRuleOperator.lessThan:
        return source.isBefore(target);
      default:
        return false;
    }
  }

  bool _boolean(bool source, SmartRuleOperator operator, dynamic value) {
    final target = value is bool ? value : value?.toString().toLowerCase() == 'true';
    return switch (operator) {
      SmartRuleOperator.isTrue => source,
      SmartRuleOperator.isFalse => !source,
      SmartRuleOperator.equals => source == target,
      _ => false,
    };
  }

  int? _numberValue(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  List<Track> _sort(
    List<Track> tracks,
    SmartSortOption option,
    Map<String, PlaybackHistory> history,
    int? limit,
  ) {
    final sorted = List<Track>.from(tracks);
    int lastPlayed(Track track) => history[track.id]?.lastPlayedAt.millisecondsSinceEpoch ?? 0;
    int plays(Track track) => history[track.id]?.playCount ?? 0;
    switch (option) {
      case SmartSortOption.recommended:
        sorted.sort((a, b) => plays(b).compareTo(plays(a)));
      case SmartSortOption.recentlyPlayed:
        sorted.sort((a, b) => lastPlayed(b).compareTo(lastPlayed(a)));
      case SmartSortOption.leastRecentlyPlayed:
        sorted.sort((a, b) => lastPlayed(a).compareTo(lastPlayed(b)));
      case SmartSortOption.mostPlayed:
        sorted.sort((a, b) => plays(b).compareTo(plays(a)));
      case SmartSortOption.leastPlayed:
        sorted.sort((a, b) => plays(a).compareTo(plays(b)));
      case SmartSortOption.title:
        sorted.sort((a, b) => a.title.compareTo(b.title));
      case SmartSortOption.artist:
        sorted.sort((a, b) => a.artist.compareTo(b.artist));
      case SmartSortOption.album:
        sorted.sort((a, b) => a.album.compareTo(b.album));
      case SmartSortOption.dateAdded:
        sorted.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      case SmartSortOption.duration:
        sorted.sort((a, b) => a.durationMs.compareTo(b.durationMs));
    }
    return limit == null ? sorted : sorted.take(limit).toList(growable: false);
  }
}
