import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/lyrics_model.dart';
import '../models/track_model.dart';
import 'storage_service.dart';

class LyricsParser {
  static final RegExp _linePattern = RegExp(
    r'^\s*((?:\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\])+)(.*)$',
  );
  static final RegExp _timestampPattern = RegExp(
    r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]',
  );

  const LyricsParser();

  ParsedLyrics parse(String trackId, String rawLyrics) {
    final lines = <LyricLine>[];
    for (final rawLine in rawLyrics.replaceAll('\r\n', '\n').split('\n')) {
      final line = _linePattern.firstMatch(rawLine);
      if (line == null) continue;
      final text = line.group(2)?.trim() ?? '';
      for (final timestamp in _timestampPattern.allMatches(line.group(1)!)) {
        final minutes = int.tryParse(timestamp.group(1)!) ?? 0;
        final seconds = int.tryParse(timestamp.group(2)!) ?? 0;
        final fractionText = timestamp.group(3);
        var fractionMs = 0;
        if (fractionText != null) {
          final rawFraction = int.tryParse(fractionText) ?? 0;
          fractionMs = fractionText.length == 1
              ? rawFraction * 100
              : fractionText.length == 2
                  ? rawFraction * 10
                  : rawFraction.clamp(0, 999).toInt();
        }
        if (seconds < 60) {
          lines.add(LyricLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: fractionMs,
            ),
            text: text,
          ));
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (lines.isNotEmpty) {
      return ParsedLyrics(trackId: trackId, lines: lines, isSynced: true);
    }
    return ParsedLyrics(
      trackId: trackId,
      lines: const [],
      isSynced: false,
      plainText: rawLyrics.trim(),
    );
  }

  /// Finds the last timestamp at or before [position]. No timer is created;
  /// callers pass the audio player's existing position updates.
  int currentLineIndex(ParsedLyrics lyrics, Duration position) {
    if (!lyrics.isSynced || lyrics.lines.isEmpty) return -1;
    var low = 0;
    var high = lyrics.lines.length - 1;
    var result = -1;
    while (low <= high) {
      final middle = low + (high - low) ~/ 2;
      if (lyrics.lines[middle].timestamp <= position) {
        result = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return result;
  }
}

/// Local-first loader for sidecar .lrc and .txt files. Failure is represented
/// as an empty result, never propagated into audio playback.
class LyricsService {
  final LyricsParser _parser;

  LyricsService({LyricsParser? parser}) : _parser = parser ?? const LyricsParser();

  Future<ParsedLyrics> loadForTrack(Track track) async {
    try {
      final cached = StorageService.getCachedLyrics(track.id);
      if (cached != null) return _parser.parse(track.id, cached);

      final raw = await _readSidecar(track.filePath);
      if (raw == null) {
        return ParsedLyrics(trackId: track.id, lines: const [], isSynced: false);
      }
      await StorageService.cacheLyrics(track.id, raw);
      return _parser.parse(track.id, raw);
    } catch (error) {
      debugPrint('LyricsService: unable to load lyrics for ${track.id}: $error');
      return ParsedLyrics(trackId: track.id, lines: const [], isSynced: false);
    }
  }

  Future<String?> _readSidecar(String path) async {
    if (kIsWeb || path.isEmpty || path.startsWith('content://')) return null;
    final sourcePath = path.startsWith('file://')
        ? Uri.tryParse(path)?.toFilePath() ?? path.replaceFirst('file://', '')
        : path;
    final source = File(sourcePath);
    final directory = source.parent;
    final filename = source.uri.pathSegments.isEmpty
        ? source.path
        : source.uri.pathSegments.last;
    final extensionIndex = filename.lastIndexOf('.');
    final basename = extensionIndex > 0 ? filename.substring(0, extensionIndex) : filename;
    for (final extension in const ['.lrc', '.txt']) {
      final candidate = File('${directory.path}${Platform.pathSeparator}$basename$extension');
      if (await candidate.exists()) return candidate.readAsString();
    }
    return null;
  }
}
