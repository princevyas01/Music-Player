import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/history_model.dart';
import 'package:music_player/models/playlist_model.dart';
import 'package:music_player/models/smart_playlist_rule_model.dart';
import 'package:music_player/models/track_model.dart';
import 'package:music_player/services/advanced_search_query_parser.dart';
import 'package:music_player/services/lyrics_service.dart';
import 'package:music_player/services/search_index_service.dart';
import 'package:music_player/services/session_service.dart';
import 'package:music_player/services/smart_playlist_builder_service.dart';

Track _track({
  required String id,
  required String title,
  required String artist,
  required String album,
  required int durationMs,
  required int year,
  String? genre,
}) =>
    Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      filePath: '/music/$id-$title.mp3',
      dateAdded: DateTime(2025, 1, int.parse(id)),
      genre: genre,
      year: year,
    );

void main() {
  final meteor = _track(
    id: '1',
    title: 'Numb',
    artist: 'Linkin Park',
    album: 'Meteora',
    durationMs: 187000,
    year: 2003,
    genre: 'Rock',
  );
  final theory = _track(
    id: '2',
    title: 'In The End',
    artist: 'Linkin Park',
    album: 'Hybrid Theory',
    durationMs: 216000,
    year: 2000,
    genre: 'Alternative Rock',
  );
  final other = _track(
    id: '3',
    title: 'Outside',
    artist: 'Elsewhere',
    album: 'Other',
    durationMs: 305000,
    year: 2003,
    genre: 'Rock',
  );

  group('AdvancedSearchQueryParser', () {
    test('parses quoted and combined documented operators', () {
      final query = const AdvancedSearchQueryParser()
          .parse('artist:"Linkin Park" album:Meteora duration:<300');
      expect(query.isValid, isTrue);
      expect(query.hasOperators, isTrue);
      expect(query.artist, 'Linkin Park');
      expect(query.album, 'Meteora');
      expect(query.durationLessThanSeconds, 300);
    });

    test('marks malformed or unknown operators for legacy fallback', () {
      expect(const AdvancedSearchQueryParser().parse('duration:300').isValid, isFalse);
      expect(const AdvancedSearchQueryParser().parse('mood:calm').isValid, isFalse);
      expect(const AdvancedSearchQueryParser().parse('artist:"Linkin').isValid, isFalse);
    });

    test('filters without altering ordinary ranked search', () {
      final index = SearchIndexService()..buildIndex([meteor, theory, other], [
          Playlist(id: 'p1', name: 'Favorites', trackIds: ['1'], createdAt: DateTime(2025)),
        ]);
      expect(index.searchAdvanced('artist:"Linkin Park" year:2003'), [meteor]);
      expect(index.searchAdvanced('playlist:Favorites'), [meteor]);
      expect(index.searchAdvanced('Numb').first, meteor);
      expect(index.searchAdvanced('duration:300'), index.search('duration:300'));
    });
  });

  group('LyricsParser', () {
    const parser = LyricsParser();

    test('parses multiple LRC timestamps and finds the active line', () {
      final lyrics = parser.parse('1', '[00:01.50][00:03.000] First line\n[00:05] Second line');
      expect(lyrics.isSynced, isTrue);
      expect(lyrics.lines.map((line) => line.timestamp.inMilliseconds), [1500, 3000, 5000]);
      expect(parser.currentLineIndex(lyrics, const Duration(milliseconds: 3200)), 1);
      expect(parser.currentLineIndex(lyrics, Duration.zero), -1);
    });

    test('keeps malformed LRC as plain text instead of throwing', () {
      final lyrics = parser.parse('1', '[not a timestamp] hello\nworld');
      expect(lyrics.isSynced, isFalse);
      expect(lyrics.plainText, contains('world'));
    });
  });

  group('SmartPlaylistBuilderService', () {
    final history = <String, PlaybackHistory>{
      '1': PlaybackHistory(
        trackId: '1',
        playCount: 5,
        completedPlayCount: 4,
        lastPlayedAt: DateTime(2025, 2),
      ),
    };

    test('supports AND rules, sorting and limits without duplicates', () {
      final definition = SmartPlaylistDefinition(
        id: 'rule-1',
        name: 'Rock from 2003',
        rules: const [
          SmartRule(field: SmartRuleField.genre, operator: SmartRuleOperator.equals, value: 'Rock'),
          SmartRule(field: SmartRuleField.year, operator: SmartRuleOperator.equals, value: 2003),
        ],
        sortOption: SmartSortOption.duration,
        limit: 1,
      );
      final result = const SmartPlaylistBuilderService().evaluate(
        definition: definition,
        tracks: [meteor, theory, other, meteor],
        history: history,
        favoriteTrackIds: const {},
        playlists: const [],
      );
      expect(result, [meteor]);
    });

    test('supports OR and playlist-membership rules', () {
      final definition = SmartPlaylistDefinition(
        id: 'rule-2',
        name: 'Mixed',
        rules: const [
          SmartRule(field: SmartRuleField.favorites, operator: SmartRuleOperator.isTrue),
          SmartRule(field: SmartRuleField.playlistMembership, operator: SmartRuleOperator.contains, value: 'Road'),
        ],
        matchAll: false,
      );
      final result = const SmartPlaylistBuilderService().evaluate(
        definition: definition,
        tracks: [meteor, theory, other],
        history: history,
        favoriteTrackIds: {'2'},
        playlists: [Playlist(id: 'p2', name: 'Road Trip', trackIds: ['3'], createdAt: DateTime(2025))],
      );
      expect(result.map((track) => track.id), containsAll(['2', '3']));
    });
  });

  group('SessionService', () {
    test('aggregates track transitions without creating playback history', () async {
      final sessions = SessionService();
      final start = DateTime(2025, 1, 1, 20);
      await sessions.recordTrackStarted('1', at: start);
      sessions.recordListenProgress(12000, at: start.add(const Duration(seconds: 12)));
      sessions.recordTrackCompleted(at: start.add(const Duration(seconds: 12)));
      await sessions.recordTrackStarted('2', at: start.add(const Duration(seconds: 13)));
      sessions.recordTrackSkipped(at: start.add(const Duration(seconds: 16)));

      final active = sessions.activeSession;
      expect(active, isNotNull);
      expect(active!.tracksStarted, 2);
      expect(active.tracksCompleted, 1);
      expect(active.tracksSkipped, 1);
      expect(active.durationMs, 12000);
      expect(active.trackIds, ['1', '2']);
    });
  });
}
