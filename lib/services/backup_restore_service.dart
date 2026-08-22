import 'dart:convert';
import '../models/track_model.dart';
import '../models/playlist_model.dart';
import 'storage_service.dart';
import 'search_index_service.dart';

class BackupRestoreService {
  static String exportPlaylistM3u(Playlist playlist, List<Track> allTracks) {
    final trackMap = {for (var t in allTracks) t.id: t};
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#PLAYLIST:${playlist.name}');

    for (var trackId in playlist.trackIds) {
      final track = trackMap[trackId];
      if (track != null) {
        final seconds = (track.durationMs / 1000).round();
        buffer.writeln('#EXTINF:$seconds,${track.artist} - ${track.title}');
        buffer.writeln(track.filePath);
      }
    }
    return buffer.toString();
  }

  static Playlist? importPlaylistM3u(String m3uContent, String playlistName, List<Track> allTracks) {
    if (m3uContent.isEmpty) return null;

    final lines = const LineSplitter().convert(m3uContent);
    final List<String> matchedTrackIds = [];

    final Map<String, Track> pathMap = {for (var t in allTracks) t.filePath.toLowerCase(): t};
    final searchIndex = SearchIndexService();
    searchIndex.buildIndex(allTracks, []);

    String? lastExtInfTitle;

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final commaIdx = line.indexOf(',');
        if (commaIdx != -1) {
          lastExtInfTitle = line.substring(commaIdx + 1).trim();
        }
      } else if (!line.startsWith('#')) {
        // Line is a file path or URI
        final pathLower = line.toLowerCase();
        if (pathMap.containsKey(pathLower)) {
          matchedTrackIds.add(pathMap[pathLower]!.id);
        } else if (lastExtInfTitle != null && lastExtInfTitle.isNotEmpty) {
          // Attempt match by #EXTINF title
          final searchRes = searchIndex.search(lastExtInfTitle);
          if (searchRes.isNotEmpty) {
            matchedTrackIds.add(searchRes.first.id);
          }
        }
        lastExtInfTitle = null;
      }
    }

    if (matchedTrackIds.isEmpty) return null;

    return Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: playlistName,
      trackIds: matchedTrackIds.toSet().toList(),
      createdAt: DateTime.now(),
    );
  }

  static String exportFullBackup() {
    return StorageService.exportBackupJson();
  }

  static Future<bool> restoreFullBackup(String jsonStr) async {
    return await StorageService.restoreBackupJson(jsonStr);
  }
}
