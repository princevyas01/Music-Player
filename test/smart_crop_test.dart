import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:music_player/services/smart_crop_service.dart';
import 'package:music_player/services/audio_artwork_extractor.dart';
import 'package:music_player/services/artwork_service.dart';

void main() {
  group('SmartCropService Tests', () {
    test('smartCropToSquare crops wide image prioritizing high-detail focal region', () {
      // Create a 300x100 image (landscape 3:1)
      final image = img.Image(width: 300, height: 100);
      img.fill(image, color: img.ColorRgb8(30, 30, 30));

      // Put vibrant high-detail content on the right side (x: 230..270, y: 30..70)
      for (int y = 30; y < 70; y++) {
        for (int x = 230; x < 270; x++) {
          image.setPixel(x, y, (x + y) % 2 == 0 ? img.ColorRgb8(255, 255, 0) : img.ColorRgb8(255, 0, 0));
        }
      }

      final cropped = SmartCropService.smartCropToSquare(image);
      expect(cropped.width, 100);
      expect(cropped.height, 100);

      // Check that the cropped 100x100 image contains the yellow/red pixels!
      bool foundVibrantPixel = false;
      for (int y = 0; y < cropped.height; y++) {
        for (int x = 0; x < cropped.width; x++) {
          final p = cropped.getPixel(x, y);
          if (p.r > 200) {
            foundVibrantPixel = true;
            break;
          }
        }
      }
      expect(foundVibrantPixel, isTrue, reason: 'The smart crop should include the vibrant focal detail on the right');
    });

    test('smartCropToSquare preserves already square images', () {
      final image = img.Image(width: 150, height: 150);
      img.fill(image, color: img.ColorRgb8(100, 100, 100));

      final cropped = SmartCropService.smartCropToSquare(image);
      expect(cropped.width, 150);
      expect(cropped.height, 150);
    });

    test('smartCropToSquare crops tall portrait image to square prioritizing focal top', () {
      final image = img.Image(width: 100, height: 250);
      img.fill(image, color: img.ColorRgb8(40, 40, 40));

      // Put focal detail near the top (e.g. face / subject at y: 20..60)
      for (int y = 20; y < 60; y++) {
        for (int x = 30; x < 70; x++) {
          image.setPixel(x, y, img.ColorRgb8(255, 200, 50));
        }
      }

      final cropped = SmartCropService.smartCropToSquare(image);
      expect(cropped.width, 100);
      expect(cropped.height, 100);

      bool foundDetail = false;
      for (int y = 0; y < cropped.height; y++) {
        for (int x = 0; x < cropped.width; x++) {
          final p = cropped.getPixel(x, y);
          if (p.r > 200 && p.g > 150) {
            foundDetail = true;
            break;
          }
        }
      }
      expect(foundDetail, isTrue, reason: 'The smart crop should include the top focal region');
    });
  });

  group('AudioArtworkExtractor Tests', () {
    test('extracts embedded APIC artwork from MP3 ID3v2 header', () async {
      final tempDir = await Directory.systemTemp.createTemp('audio_art_test_');
      try {
        final mp3File = File('${tempDir.path}/test_song.mp3');

        // Synthetic JPEG bytes (SOI marker 0xFF 0xD8 0xFF ... EOI 0xFF 0xD9)
        final fakeJpeg = Uint8List(200);
        fakeJpeg[0] = 0xFF;
        fakeJpeg[1] = 0xD8;
        fakeJpeg[2] = 0xFF;
        fakeJpeg[3] = 0xE0;
        for (int i = 4; i < 198; i++) {
          fakeJpeg[i] = i % 256;
        }
        fakeJpeg[198] = 0xFF;
        fakeJpeg[199] = 0xD9;

        // Construct ID3v2.3 buffer with APIC frame
        final frameHeader = Uint8List.fromList([
          0x41, 0x50, 0x49, 0x43, // 'APIC'
          0x00, 0x00, 0x00, 204,   // size: 4 + 200 bytes
          0x00, 0x00,             // flags
          0x00,                   // encoding
          0x69, 0x6D, 0x67,       // 'img' mime
        ]);

        final tagData = BytesBuilder();
        tagData.add(frameHeader);
        tagData.add(fakeJpeg);
        final tagBytes = tagData.toBytes();

        final totalTagSize = tagBytes.length;
        // ID3 header (10 bytes)
        final id3Header = Uint8List.fromList([
          0x49, 0x44, 0x33, // 'ID3'
          0x03, 0x00,       // version 2.3.0
          0x00,             // flags
          (totalTagSize >> 21) & 0x7F,
          (totalTagSize >> 14) & 0x7F,
          (totalTagSize >> 7) & 0x7F,
          totalTagSize & 0x7F,
        ]);

        final fileBuilder = BytesBuilder();
        fileBuilder.add(id3Header);
        fileBuilder.add(tagBytes);
        fileBuilder.add(Uint8List(500)); // fake audio payload

        await mp3File.writeAsBytes(fileBuilder.toBytes());

        final extracted = await AudioArtworkExtractor.extractArtworkFromFile(mp3File.path);
        expect(extracted, isNotNull);
        expect(extracted!.length, equals(200));
        expect(extracted[0], equals(0xFF));
        expect(extracted[1], equals(0xD8));
        expect(extracted[extracted.length - 2], equals(0xFF));
        expect(extracted[extracted.length - 1], equals(0xD9));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('extracts companion cover image from audio directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('companion_art_test_');
      try {
        final audioFile = File('${tempDir.path}/track01.mp3');
        await audioFile.writeAsBytes(Uint8List(1000)); // audio without embedded art

        final coverFile = File('${tempDir.path}/cover.jpg');
        final fakeCover = Uint8List(150);
        fakeCover[0] = 0xFF;
        fakeCover[1] = 0xD8;
        fakeCover[2] = 0xFF;
        fakeCover[148] = 0xFF;
        fakeCover[149] = 0xD9;
        await coverFile.writeAsBytes(fakeCover);

        final extracted = await AudioArtworkExtractor.extractArtworkFromFile(audioFile.path);
        expect(extracted, isNotNull);
        expect(extracted!.length, equals(150));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('ArtworkService Tests', () {
    test('getCachedArtworkPath returns null for untracked tracks', () {
      expect(ArtworkService.getCachedArtworkPath('untracked_99999'), isNull);
    });

    test('setCachedArtworkPath updates and retrieves cached paths', () {
      const trackId = 'test_track_123';
      const fakePath = '/tmp/art_test_track_123.jpg';

      ArtworkService.setCachedArtworkPath(trackId, fakePath);
      expect(ArtworkService.getCachedArtworkPath(trackId), equals(fakePath));

      ArtworkService.setCachedArtworkPath(trackId, null);
      expect(ArtworkService.getCachedArtworkPath(trackId), isNull);
    });
  });
}
