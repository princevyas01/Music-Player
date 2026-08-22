import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/track_model.dart';
import 'package:music_player/models/playlist_model.dart';
import 'package:music_player/services/search_index_service.dart';

void main() {
  group('SearchIndexService Tests', () {
    late SearchIndexService searchIndex;

    final t1 = Track(
      id: '1',
      title: 'In The End',
      artist: 'Linkin Park',
      album: 'Hybrid Theory',
      durationMs: 216000,
      filePath: '/music/1.mp3',
      dateAdded: DateTime.fromMillisecondsSinceEpoch(1000),
      genre: 'Alternative Rock',
      year: 2000,
    );

    final t2 = Track(
      id: '2',
      title: 'Numb',
      artist: 'Linkin Park',
      album: 'Meteora',
      durationMs: 187000,
      filePath: '/music/2.mp3',
      dateAdded: DateTime.fromMillisecondsSinceEpoch(2000),
      genre: 'Rock',
      year: 2003,
    );

    final t3 = Track(
      id: '3',
      title: 'End of the Line',
      artist: 'The Travelling Wilburys',
      album: 'Volume 1',
      durationMs: 205000,
      filePath: '/music/3.mp3',
      dateAdded: DateTime.fromMillisecondsSinceEpoch(3000),
      genre: 'Classic Rock',
      year: 1988,
    );

    final p1 = Playlist(
      id: 'p1',
      name: 'Favorite Rock Hits',
      trackIds: ['1', '2'],
      createdAt: DateTime.now(),
    );

    setUp(() {
      searchIndex = SearchIndexService();
      searchIndex.buildIndex([t1, t2, t3], [p1]);
    });

    test('Case insensitivity and whitespace tolerance', () {
      final res1 = searchIndex.search('LINKIN PARK');
      expect(res1.length, equals(2));
      expect(res1.map((t) => t.id), containsAll(['1', '2']));

      final res2 = searchIndex.search('  linkin   park  ');
      expect(res2.length, equals(2));

      final res3 = searchIndex.search('Linkin Park');
      expect(res3.length, equals(2));
    });

    test('Exact title match ranks higher than word match', () {
      final results = searchIndex.search('Numb');
      expect(results.first.id, equals('2'));
    });

    test('Searching word inside title (substring/word match)', () {
      final results = searchIndex.search('End');
      expect(results.length, equals(2));
      expect(results.map((t) => t.id), containsAll(['1', '3']));
    });

    test('Searching by album name', () {
      final results = searchIndex.search('Meteora');
      expect(results.length, equals(1));
      expect(results.first.id, equals('2'));
    });

    test('Searching by genre and year', () {
      final genreResults = searchIndex.search('Alternative');
      expect(genreResults.length, equals(1));
      expect(genreResults.first.id, equals('1'));

      final yearResults = searchIndex.search('2003');
      expect(yearResults.length, equals(1));
      expect(yearResults.first.id, equals('2'));
    });

    test('Searching by playlist name', () {
      final results = searchIndex.search('Favorite Rock');
      expect(results.length, equals(2));
    });

    test('Empty query returns all tracks', () {
      final results = searchIndex.search('');
      expect(results.length, equals(3));
    });

    test('Normalization strips punctuation and accents', () {
      final normalized = SearchIndexService.normalize('Café - (Rêve) #1');
      expect(normalized, equals('cafe reve 1'));
    });

    test('Filename-based exact, prefix, substring, and character sequence matching', () {
      final t4 = Track(
        id: '4',
        title: 'Kesariya',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        durationMs: 268000,
        filePath: '/storage/emulated/0/Music/01 - Arijit Singh - Kesariya Official Audio.mp3',
        dateAdded: DateTime.now(),
      );

      final searchIndex2 = SearchIndexService();
      searchIndex2.buildIndex([t4], []);

      // Test character sequence matches from prompt section 56:
      // arijit, rijit, singh, kes, kesariya, sariya, official, audio, 01
      for (final q in ['arijit', 'rijit', 'singh', 'kes', 'kesariya', 'sariya', 'official', 'audio', '01', '01 - Arijit', 'official audio.mp3']) {
        final res = searchIndex2.search(q);
        expect(res.isNotEmpty, isTrue, reason: 'Failed search for query "$q"');
        expect(res.first.id, equals('4'));
      }
    });

    test('Filename remains searchable after metadata override', () {
      // Original filePath is track001.mp3
      final t5 = Track(
        id: '5',
        title: 'Custom Title',
        artist: 'Custom Artist',
        album: 'Custom Album',
        durationMs: 180000,
        filePath: '/music/track001_rock_heavy_metal.mp3',
        dateAdded: DateTime.now(),
      );

      final searchIndex3 = SearchIndexService();
      searchIndex3.buildIndex([t5], []);

      // Both new title and original filename must be searchable
      final resTitle = searchIndex3.search('Custom Title');
      expect(resTitle.map((t) => t.id), contains('5'));

      final resFilename = searchIndex3.search('track001');
      expect(resFilename.map((t) => t.id), contains('5'));

      final resFnMiddle = searchIndex3.search('heavy_metal');
      expect(resFnMiddle.map((t) => t.id), contains('5'));
    });
  });
}
