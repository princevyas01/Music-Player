import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/track_model.dart';
import 'search_index_service.dart';

class DuplicateGroup {
  final String key;
  final List<Track> tracks;

  DuplicateGroup({required this.key, required this.tracks});
}

class LibraryAuditReport {
  final List<DuplicateGroup> duplicateGroups;
  final List<Track> brokenTracks;

  LibraryAuditReport({
    required this.duplicateGroups,
    required this.brokenTracks,
  });
}

class LibraryAuditService {
  static List<DuplicateGroup> findDuplicates(List<Track> tracks) {
    final Map<String, List<Track>> groups = {};

    for (final track in tracks) {
      final titleNorm = SearchIndexService.normalize(track.title);
      final artistNorm = SearchIndexService.normalize(track.artist);
      final durSec = (track.durationMs / 1000).round();

      // Key based on normalized title, artist, and duration rounded to nearest 2 seconds
      final key = '${titleNorm}_${artistNorm}_${durSec ~/ 2}';
      groups.putIfAbsent(key, () => []).add(track);
    }

    final List<DuplicateGroup> duplicates = [];
    groups.forEach((key, list) {
      if (list.length > 1) {
        duplicates.add(DuplicateGroup(key: key, tracks: list));
      }
    });

    return duplicates;
  }

  static Future<List<Track>> checkBrokenTracks(List<Track> tracks) async {
    final List<Track> broken = [];

    for (final track in tracks) {
      if (kIsWeb) continue;

      final path = track.filePath;
      if (path.isEmpty) {
        broken.add(track);
        continue;
      }

      if (path.startsWith('content://')) {
        // Content URIs managed by MediaStore — if media query returned it, assume valid unless file path fails
        continue;
      }

      if (path.startsWith('file://') || path.startsWith('/')) {
        final filePath = path.startsWith('file://') ? path.replaceFirst('file://', '') : path;
        try {
          final file = File(filePath);
          if (!await file.exists()) {
            broken.add(track);
          }
        } catch (_) {
          broken.add(track);
        }
      }
    }

    return broken;
  }

  static Future<LibraryAuditReport> runAudit(List<Track> tracks) async {
    final duplicates = findDuplicates(tracks);
    final broken = await checkBrokenTracks(tracks);
    return LibraryAuditReport(
      duplicateGroups: duplicates,
      brokenTracks: broken,
    );
  }
}
