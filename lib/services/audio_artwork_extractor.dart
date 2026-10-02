import 'dart:io';
import 'package:flutter/foundation.dart';

/// Pure Dart, zero-dependency extractor for embedded artwork in audio files
/// (MP3 ID3v2 APIC, MP4/M4A covr, FLAC METADATA_BLOCK_PICTURE, and companion cover images).
class AudioArtworkExtractor {
  /// Attempts to extract raw artwork image bytes from an audio file.
  /// Checks embedded tags first, then looks for companion image files in the directory.
  static Future<Uint8List?> extractArtworkFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final len = await file.length();
      if (len < 128) return null;

      // 1. Try reading embedded artwork from audio headers/tags
      final embedded = await _extractEmbedded(file, len);
      if (embedded != null && embedded.isNotEmpty) {
        return embedded;
      }

      // 2. Try companion image in the same directory (e.g. cover.jpg, folder.jpg)
      final companion = await _findCompanionArtwork(file);
      if (companion != null && companion.isNotEmpty) {
        return companion;
      }
    } catch (e) {
      debugPrint('AudioArtworkExtractor failed for $filePath: $e');
    }
    return null;
  }

  /// Synchronously or streamed extraction from file headers
  static Future<Uint8List?> _extractEmbedded(File file, int fileLength) async {
    final ext = file.path.split('.').last.toLowerCase();

    // Read initial chunk (up to 8 MB) which contains headers/ID3/moov
    final readSize = fileLength > 8 * 1024 * 1024 ? 8 * 1024 * 1024 : fileLength;
    final raf = await file.open(mode: FileMode.read);
    try {
      final bytes = await raf.read(readSize);

      if (ext == 'mp3' || (bytes.length >= 3 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33)) {
        final mp3Art = _extractFromId3v2(bytes);
        if (mp3Art != null) return mp3Art;
      }

      if (ext == 'm4a' || ext == 'mp4' || ext == 'aac') {
        final mp4Art = _extractFromMp4(bytes);
        if (mp4Art != null) return mp4Art;
      }

      if (ext == 'flac' || (bytes.length >= 4 && bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43)) {
        final flacArt = _extractFromFlac(bytes);
        if (flacArt != null) return flacArt;
      }

      // Fallback: heuristic scan for embedded JPEG/PNG magic signatures inside metadata
      return _scanForImage(bytes, maxOffset: bytes.length);
    } finally {
      await raf.close();
    }
  }

  /// Extracts APIC (Attached Picture) frame from ID3v2
  static Uint8List? _extractFromId3v2(Uint8List bytes) {
    if (bytes.length < 10) return null;
    // ID3 header: 'ID3' (3 bytes), version (2 bytes), flags (1 byte), size (4 synchsafe bytes)
    if (bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) return null;

    final version = bytes[3];
    final tagSize = ((bytes[6] & 0x7F) << 21) |
        ((bytes[7] & 0x7F) << 14) |
        ((bytes[8] & 0x7F) << 7) |
        (bytes[9] & 0x7F);

    final end = (tagSize + 10).clamp(10, bytes.length);
    int offset = 10;

    if (version == 2) {
      // ID3v2.2: 3-char frame IDs, 3-byte size
      while (offset + 6 < end) {
        final id = String.fromCharCodes(bytes.sublist(offset, offset + 3));
        if (id == '\x00\x00\x00') break;
        final size = (bytes[offset + 3] << 16) | (bytes[offset + 4] << 8) | bytes[offset + 5];
        offset += 6;
        if (offset + size > end) break;
        if (id == 'PIC') {
          final frame = bytes.sublist(offset, offset + size);
          final img = _scanForImage(frame);
          if (img != null) return img;
        }
        offset += size;
      }
    } else {
      // ID3v2.3 & ID3v2.4: 4-char frame IDs, 4-byte size, 2-byte flags
      while (offset + 10 < end) {
        if (bytes[offset] == 0) break; // Padding reached
        final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final int size;
        if (version == 4) {
          // ID3v2.4 uses synchsafe frame sizes
          size = ((bytes[offset + 4] & 0x7F) << 21) |
              ((bytes[offset + 5] & 0x7F) << 14) |
              ((bytes[offset + 6] & 0x7F) << 7) |
              (bytes[offset + 7] & 0x7F);
        } else {
          // ID3v2.3 uses regular 32-bit big-endian
          size = (bytes[offset + 4] << 24) |
              (bytes[offset + 5] << 16) |
              (bytes[offset + 6] << 8) |
              bytes[offset + 7];
        }

        offset += 10;
        if (size <= 0 || offset + size > end) break;

        if (id == 'APIC') {
          final frame = bytes.sublist(offset, offset + size);
          final img = _scanForImage(frame);
          if (img != null) return img;
        }
        offset += size;
      }
    }

    return null;
  }

  /// Extracts covr box from MP4/M4A metadata
  static Uint8List? _extractFromMp4(Uint8List bytes) {
    if (bytes.length < 16) return null;
    // Search for 'covr' fourcc
    for (int i = 0; i < bytes.length - 8; i++) {
      if (bytes[i] == 0x63 && // 'c'
          bytes[i + 1] == 0x6F && // 'o'
          bytes[i + 2] == 0x76 && // 'v'
          bytes[i + 3] == 0x72) { // 'r'
        // Within the covr atom, search for image data box or direct magic bytes
        final boxStart = i + 4;
        final searchLen = (bytes.length - boxStart).clamp(0, 1024 * 1024);
        final slice = bytes.sublist(boxStart, boxStart + searchLen);
        final img = _scanForImage(slice);
        if (img != null) return img;
      }
    }
    return null;
  }

  /// Extracts METADATA_BLOCK_PICTURE from FLAC
  static Uint8List? _extractFromFlac(Uint8List bytes) {
    if (bytes.length < 8) return null;
    if (bytes[0] != 0x66 || bytes[1] != 0x4C || bytes[2] != 0x61 || bytes[3] != 0x43) {
      return null;
    }

    int offset = 4;
    while (offset + 4 < bytes.length) {
      final headerByte = bytes[offset];
      final isLast = (headerByte & 0x80) != 0;
      final blockType = headerByte & 0x7F;
      final blockSize = (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
      offset += 4;

      if (offset + blockSize > bytes.length) break;

      if (blockType == 6) {
        // METADATA_BLOCK_PICTURE
        final block = bytes.sublist(offset, offset + blockSize);
        final img = _scanForImage(block);
        if (img != null) return img;
      }

      if (isLast) break;
      offset += blockSize;
    }

    return null;
  }

  /// Scans byte slice for JPEG or PNG image signatures and extracts the image payload
  static Uint8List? _scanForImage(Uint8List slice, {int? maxOffset}) {
    final limit = (maxOffset != null && maxOffset < slice.length) ? maxOffset : slice.length;

    // 1. JPEG SOI: FF D8 FF
    for (int i = 0; i < limit - 3; i++) {
      if (slice[i] == 0xFF && slice[i + 1] == 0xD8 && slice[i + 2] == 0xFF) {
        // Find JPEG EOI: FF D9
        int eoi = limit;
        for (int j = limit - 2; j >= i + 3; j--) {
          if (slice[j] == 0xFF && slice[j + 1] == 0xD9) {
            eoi = j + 2;
            break;
          }
        }
        final candidate = slice.sublist(i, eoi);
        if (candidate.length >= 100) return candidate;
      }
    }

    // 2. PNG: 89 50 4E 47 0D 0A 1A 0A
    for (int i = 0; i < limit - 8; i++) {
      if (slice[i] == 0x89 &&
          slice[i + 1] == 0x50 &&
          slice[i + 2] == 0x4E &&
          slice[i + 3] == 0x47 &&
          slice[i + 4] == 0x0D &&
          slice[i + 5] == 0x0A &&
          slice[i + 6] == 0x1A &&
          slice[i + 7] == 0x0A) {
        // Find PNG IEND: 49 45 4E 44 AE 42 60 82
        int iend = limit;
        for (int j = limit - 8; j >= i + 8; j--) {
          if (slice[j] == 0x49 &&
              slice[j + 1] == 0x45 &&
              slice[j + 2] == 0x4E &&
              slice[j + 3] == 0x44) {
            iend = (j + 8 <= limit) ? j + 8 : limit;
            break;
          }
        }
        final candidate = slice.sublist(i, iend);
        if (candidate.length >= 100) return candidate;
      }
    }

    return null;
  }

  /// Checks for companion images in the audio file's folder (cover.jpg, folder.jpg, etc.)
  static Future<Uint8List?> _findCompanionArtwork(File audioFile) async {
    try {
      final parentDir = audioFile.parent;
      if (!await parentDir.exists()) return null;

      final baseName = audioFile.path.split(Platform.pathSeparator).last;
      final dotIdx = baseName.lastIndexOf('.');
      final nameWithoutExt = dotIdx > 0 ? baseName.substring(0, dotIdx) : baseName;

      final candidateNames = [
        'cover.jpg',
        'cover.png',
        'cover.jpeg',
        'folder.jpg',
        'folder.png',
        'album.jpg',
        'album.png',
        'artwork.jpg',
        'artwork.png',
        '$nameWithoutExt.jpg',
        '$nameWithoutExt.png',
      ];

      for (final name in candidateNames) {
        final imgFile = File('${parentDir.path}/$name');
        if (await imgFile.exists()) {
          final bytes = await imgFile.readAsBytes();
          if (bytes.length >= 100) {
            return bytes;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
