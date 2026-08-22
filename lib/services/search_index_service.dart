import '../models/track_model.dart';
import '../models/playlist_model.dart';

class SearchResult {
  final Track track;
  final int score;
  final String matchSource;

  SearchResult({
    required this.track,
    required this.score,
    required this.matchSource,
  });
}

class _IndexedTrack {
  final Track track;
  final String titleNorm;
  final String artistNorm;
  final String albumNorm;
  final String albumArtistNorm;
  final String genreNorm;
  final String yearStr;
  final String rawFilename;
  final String rawFilenameLower;
  final String filenameNorm;

  _IndexedTrack({
    required this.track,
    required this.titleNorm,
    required this.artistNorm,
    required this.albumNorm,
    required this.albumArtistNorm,
    required this.genreNorm,
    required this.yearStr,
    required this.rawFilename,
    required this.rawFilenameLower,
    required this.filenameNorm,
  });
}

class SearchIndexService {
  final List<_IndexedTrack> _indexedTracks = [];
  final List<Track> _tracks = [];
  final List<Playlist> _playlists = [];

  static String extractFilename(String filePath) {
    if (filePath.isEmpty) return '';
    final normalizedPath = filePath.replaceAll('\\', '/');
    final parts = normalizedPath.split('/');
    return parts.isNotEmpty ? parts.last : filePath;
  }

  static String normalize(String text) {
    if (text.isEmpty) return '';
    String normalized = text.toLowerCase();

    // Diacritics & Accents removal
    normalized = normalized
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[ç]'), 'c');

    // Punctuation and special symbols to space
    normalized = normalized.replaceAll(RegExp(r'[^\w\s]'), ' ');
    // Collapse whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  void buildIndex(List<Track> tracks, List<Playlist> playlists) {
    _tracks.clear();
    _tracks.addAll(tracks);
    _playlists.clear();
    _playlists.addAll(playlists);

    _indexedTracks.clear();
    for (final track in tracks) {
      final rawFilename = extractFilename(track.filePath);
      _indexedTracks.add(_IndexedTrack(
        track: track,
        titleNorm: normalize(track.title),
        artistNorm: normalize(track.artist),
        albumNorm: normalize(track.album),
        albumArtistNorm: normalize(track.albumArtist ?? ''),
        genreNorm: normalize(track.genre ?? ''),
        yearStr: track.year?.toString() ?? '',
        rawFilename: rawFilename,
        rawFilenameLower: rawFilename.toLowerCase(),
        filenameNorm: normalize(rawFilename),
      ));
    }
  }

  List<Track> search(String query) {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) return List.unmodifiable(_tracks);

    final rawQueryLower = rawQuery.toLowerCase();
    final normalizedQuery = normalize(rawQuery);
    if (normalizedQuery.isEmpty && rawQueryLower.isEmpty) return List.unmodifiable(_tracks);

    final queryTokens = normalizedQuery.isNotEmpty ? normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList() : <String>[];

    // Map track ID to playlist names
    final Map<String, Set<String>> trackPlaylistMap = {};
    for (var p in _playlists) {
      final pNameNorm = normalize(p.name);
      for (var tId in p.trackIds) {
        trackPlaylistMap.putIfAbsent(tId, () => {}).add(pNameNorm);
      }
    }

    final List<SearchResult> results = [];

    for (final item in _indexedTracks) {
      final track = item.track;
      final titleNorm = item.titleNorm;
      final artistNorm = item.artistNorm;
      final albumNorm = item.albumNorm;
      final albumArtistNorm = item.albumArtistNorm;
      final genreNorm = item.genreNorm;
      final yearStr = item.yearStr;
      final playlistNames = trackPlaylistMap[track.id] ?? {};

      final rawFilenameLower = item.rawFilenameLower;
      final filenameNorm = item.filenameNorm;

      int score = 0;
      String matchSource = '';

      // 1. Title matching
      if (titleNorm.isNotEmpty) {
        if (titleNorm == normalizedQuery) {
          score += 1000;
          matchSource = 'title';
        } else if (titleNorm.startsWith(normalizedQuery)) {
          score += 700;
          matchSource = 'title';
        } else if (titleNorm.contains(normalizedQuery) || (rawQueryLower.isNotEmpty && track.title.toLowerCase().contains(rawQueryLower))) {
          score += 400;
          matchSource = 'title';
        } else if (queryTokens.isNotEmpty) {
          final titleWords = titleNorm.split(' ');
          for (var token in queryTokens) {
            if (titleWords.any((w) => w.startsWith(token))) {
              score += 500;
              matchSource = 'title';
              break;
            }
          }
        }
      }

      // 2. Filename matching (Raw & Normalized)
      int filenameScore = 0;
      if (filenameNorm.isNotEmpty || rawFilenameLower.isNotEmpty) {
        if ((normalizedQuery.isNotEmpty && filenameNorm == normalizedQuery) || rawFilenameLower == rawQueryLower) {
          filenameScore = 950;
        } else if ((normalizedQuery.isNotEmpty && filenameNorm.startsWith(normalizedQuery)) || rawFilenameLower.startsWith(rawQueryLower)) {
          filenameScore = 650;
        } else if (queryTokens.isNotEmpty && filenameNorm.split(' ').any((w) => queryTokens.any((t) => w.startsWith(t)))) {
          filenameScore = 500;
        } else if ((normalizedQuery.isNotEmpty && filenameNorm.contains(normalizedQuery)) || rawFilenameLower.contains(rawQueryLower)) {
          filenameScore = 450;
        }
      }
      if (filenameScore > 0) {
        score += filenameScore;
        if (matchSource.isEmpty) matchSource = 'filename';
      }

      // 3. Artist matching
      if (artistNorm.isNotEmpty) {
        if (artistNorm == normalizedQuery) {
          score += 400;
          if (matchSource.isEmpty) matchSource = 'artist';
        } else if (artistNorm.startsWith(normalizedQuery)) {
          score += 300;
          if (matchSource.isEmpty) matchSource = 'artist';
        } else if (artistNorm.contains(normalizedQuery) || (rawQueryLower.isNotEmpty && track.artist.toLowerCase().contains(rawQueryLower))) {
          score += 250;
          if (matchSource.isEmpty) matchSource = 'artist';
        } else if (queryTokens.isNotEmpty) {
          final artistWords = artistNorm.split(' ');
          for (var token in queryTokens) {
            if (artistWords.any((w) => w.startsWith(token))) {
              score += 180;
              if (matchSource.isEmpty) matchSource = 'artist';
              break;
            }
          }
        }
      }

      // 4. Album matching
      if (albumNorm.isNotEmpty) {
        if (albumNorm == normalizedQuery) {
          score += 350;
          if (matchSource.isEmpty) matchSource = 'album';
        } else if (albumNorm.startsWith(normalizedQuery) || albumNorm.contains(normalizedQuery) || (rawQueryLower.isNotEmpty && track.album.toLowerCase().contains(rawQueryLower))) {
          score += 220;
          if (matchSource.isEmpty) matchSource = 'album';
        }
      }

      // 5. Playlist name matching
      if (normalizedQuery.isNotEmpty) {
        for (var pName in playlistNames) {
          if (pName.contains(normalizedQuery)) {
            score += 180;
            if (matchSource.isEmpty) matchSource = 'playlist';
            break;
          }
        }
      }

      // 6. Genre matching
      if (genreNorm.isNotEmpty && normalizedQuery.isNotEmpty && (genreNorm.startsWith(normalizedQuery) || genreNorm.contains(normalizedQuery))) {
        score += 120;
        if (matchSource.isEmpty) matchSource = 'genre';
      }

      // 7. Year matching
      if (yearStr.isNotEmpty && (yearStr == rawQuery || yearStr.startsWith(rawQuery))) {
        score += 100;
        if (matchSource.isEmpty) matchSource = 'year';
      }

      // 8. Other metadata matching (albumArtist, etc.)
      if (albumArtistNorm.isNotEmpty && normalizedQuery.isNotEmpty && albumArtistNorm.contains(normalizedQuery)) {
        score += 60;
        if (matchSource.isEmpty) matchSource = 'metadata';
      }

      if (score > 0) {
        results.add(SearchResult(track: track, score: score, matchSource: matchSource));
      }
    }

    results.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      final titleCompare = a.track.title.toLowerCase().compareTo(b.track.title.toLowerCase());
      if (titleCompare != 0) return titleCompare;
      final artistCompare = a.track.artist.toLowerCase().compareTo(b.track.artist.toLowerCase());
      if (artistCompare != 0) return artistCompare;
      final albumCompare = a.track.album.toLowerCase().compareTo(b.track.album.toLowerCase());
      if (albumCompare != 0) return albumCompare;
      final fnA = extractFilename(a.track.filePath).toLowerCase();
      final fnB = extractFilename(b.track.filePath).toLowerCase();
      return fnA.compareTo(fnB);
    });

    return results.map((r) => r.track).toList();
  }
}
