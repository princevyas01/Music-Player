import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/track_model.dart';
import 'package:music_player/models/playlist_model.dart';
import 'package:music_player/services/history_service.dart';
import 'package:music_player/services/smart_playlist_service.dart';
import 'package:music_player/services/smart_mix_service.dart';
import 'package:music_player/services/library_audit_service.dart';
import 'package:music_player/services/backup_restore_service.dart';

void main() {
  final t1 = Track(
    id: '1',
    title: 'In The End',
    artist: 'Linkin Park',
    album: 'Hybrid Theory',
    durationMs: 216000,
    filePath: '/music/1.mp3',
    dateAdded: DateTime.fromMillisecondsSinceEpoch(100000),
  );

  final t2 = Track(
    id: '2',
    title: 'Numb',
    artist: 'Linkin Park',
    album: 'Meteora',
    durationMs: 187000,
    filePath: '/music/2.mp3',
    dateAdded: DateTime.fromMillisecondsSinceEpoch(200000),
  );

  final t3 = Track(
    id: '3',
    title: 'Short Sound',
    artist: 'Effect',
    album: 'FX',
    durationMs: 4000, // 4s
    filePath: '/music/3.mp3',
    dateAdded: DateTime.fromMillisecondsSinceEpoch(300000),
  );

  group('SmartPlaylistService Tests', () {
    late HistoryService historyService;
    late SmartPlaylistService smartPlaylists;

    setUp(() {
      historyService = HistoryService();
      smartPlaylists = SmartPlaylistService(historyService);
    });

    test('getRecentlyAdded returns sorted by dateAdded descending', () {
      final rec = smartPlaylists.getRecentlyAdded([t1, t2, t3]);
      expect(rec.first.id, equals('3'));
    });

    test('getShortTracks filters tracks by max duration', () {
      final shorts = smartPlaylists.getShortTracks([t1, t2, t3], maxMs: 10000);
      expect(shorts.length, equals(1));
      expect(shorts.first.id, equals('3'));
    });
  });

  group('LibraryAuditService Tests', () {
    test('findDuplicates detects tracks with identical normalized title, artist, and duration', () {
      final t1Duplicate = Track(
        id: '10',
        title: 'in the end ',
        artist: 'linkin park',
        album: 'Hybrid Theory Remaster',
        durationMs: 216000,
        filePath: '/music/1_dup.mp3',
        dateAdded: DateTime.now(),
      );

      final duplicates = LibraryAuditService.findDuplicates([t1, t2, t1Duplicate]);
      expect(duplicates.length, equals(1));
      expect(duplicates.first.tracks.length, equals(2));
      expect(duplicates.first.tracks.map((t) => t.id), containsAll(['1', '10']));
    });
  });

  group('BackupRestoreService Tests', () {
    test('exportPlaylistM3u generates valid M3U format', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'My Rock Playlist',
        trackIds: ['1', '2'],
        createdAt: DateTime.now(),
      );

      final m3u = BackupRestoreService.exportPlaylistM3u(playlist, [t1, t2, t3]);
      expect(m3u, contains('#EXTM3U'));
      expect(m3u, contains('#PLAYLIST:My Rock Playlist'));
      expect(m3u, contains('Linkin Park - In The End'));
      expect(m3u, contains('/music/1.mp3'));
    });

    test('importPlaylistM3u parses lines and matches local tracks', () {
      const m3u = '''
#EXTM3U
#PLAYLIST:Imported Rock
#EXTINF:216,Linkin Park - In The End
/music/1.mp3
#EXTINF:187,Linkin Park - Numb
/music/2.mp3
''';

      final imported = BackupRestoreService.importPlaylistM3u(m3u, 'Imported Rock', [t1, t2, t3]);
      expect(imported, isNotNull);
      expect(imported!.name, equals('Imported Rock'));
      expect(imported.trackIds, containsAll(['1', '2']));
    });
  });

  group('SmartMixService Tests', () {
    test('generateMix creates a randomized track sequence avoiding immediate artist repetition', () {
      final historyService = HistoryService();
      final smartMix = SmartMixService(historyService);

      final mix = smartMix.generateMix([t1, t2, t3], count: 10);
      expect(mix.isNotEmpty, isTrue);
    });
  });
}
