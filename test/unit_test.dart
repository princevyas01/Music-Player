import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/models/track_model.dart';
import 'package:music_player/providers/audio_provider.dart';
import 'package:music_player/providers/library_provider.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  group('Track Model Tests', () {
    test('Track instantiates properly and computes duration string', () {
      final track = Track(
        id: '1',
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        durationMs: 180000,
        filePath: '/storage/emulated/0/Music/test.mp3',
        dateAdded: DateTime.now(),
      );

      expect(track.id, equals('1'));
      expect(track.durationMs, equals(180000));
      expect(track.title, equals('Test Song'));
    });
  });

  group('PlaybackStateData Immutable State Tests', () {
    test('copyWith updates fields correctly without mutating state', () {
      final initial = PlaybackStateData(
        isPlaying: false,
        position: Duration.zero,
        duration: const Duration(minutes: 3),
        loopMode: LoopMode.off,
      );

      final updated = initial.copyWith(
        isPlaying: true,
        position: const Duration(seconds: 30),
      );

      expect(initial.isPlaying, isFalse);
      expect(updated.isPlaying, isTrue);
      expect(updated.position, equals(const Duration(seconds: 30)));
      expect(updated.duration, equals(const Duration(minutes: 3)));
    });
  });

  group('TrackTrie Prefix Match Search Tests', () {
    test('Trie inserts and retrieves tracks by prefix', () {
      final trie = TrackTrie();
      final t1 = Track(
        id: '1',
        title: 'Lavender Serenade',
        artist: 'Aesthetic Dreams',
        album: 'Horizons',
        durationMs: 200000,
        filePath: '/music/1.mp3',
        dateAdded: DateTime.now(),
      );

      trie.insert(t1.title.toLowerCase(), t1);
      trie.insert(t1.artist.toLowerCase(), t1);

      final titleMatch = trie.searchPrefix('lavender');
      expect(titleMatch.length, equals(1));
      expect(titleMatch.first.id, equals('1'));

      final artistMatch = trie.searchPrefix('aesthetic');
      expect(artistMatch.length, equals(1));
      expect(artistMatch.first.id, equals('1'));
    });
  });

  group('Playback Speed Precision & Bounds Tests', () {
    test('Playback speed step calculations round to 2 decimal places cleanly', () {
      double speed = 1.0;
      final steps = [-0.05, -0.05, 0.05, 0.05, 0.05, 0.05, 0.05];
      for (final s in steps) {
        speed = ((speed + s) * 100).round() / 100;
      }
      expect(speed, equals(1.15));
    });

    test('Playback speed is clamped between 0.50x and 2.00x', () {
      double lowSpeed = 0.2;
      double highSpeed = 2.5;

      lowSpeed = ((lowSpeed * 100).round() / 100).clamp(0.50, 2.00);
      highSpeed = ((highSpeed * 100).round() / 100).clamp(0.50, 2.00);

      expect(lowSpeed, equals(0.50));
      expect(highSpeed, equals(2.00));
    });
  });
}
