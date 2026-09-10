import '../models/history_model.dart';
import '../models/track_model.dart';

class ArtistProfile {
  final String name;
  final List<Track> tracks;
  final List<Track> popularTracks;
  final List<Track> recentlyPlayedTracks;
  final List<Track> latestAdditions;
  final List<String> albums;
  final List<String> similarArtists;
  final int listeningDurationMs;
  final int playCount;
  final double completionRate;

  const ArtistProfile({
    required this.name,
    required this.tracks,
    required this.popularTracks,
    required this.recentlyPlayedTracks,
    required this.latestAdditions,
    required this.albums,
    required this.similarArtists,
    required this.listeningDurationMs,
    required this.playCount,
    required this.completionRate,
  });

  int get trackCount => tracks.length;
  int get albumCount => albums.length;
}

class ArtistService {
  const ArtistService();

  ArtistProfile buildProfile(
    String artist,
    List<Track> library,
    Map<String, PlaybackHistory> history,
  ) {
    final tracks = library.where((track) => track.artist == artist).toList();
    final albumSet = tracks.map((track) => track.album).where((album) => album.isNotEmpty).toSet();
    final orderedByPopularity = List<Track>.from(tracks)
      ..sort((a, b) => (history[b.id]?.playCount ?? 0).compareTo(history[a.id]?.playCount ?? 0));
    final orderedByRecent = List<Track>.from(tracks)
      ..sort((a, b) => (history[b.id]?.lastPlayedAt ?? DateTime(0))
          .compareTo(history[a.id]?.lastPlayedAt ?? DateTime(0)));
    final orderedByAdded = List<Track>.from(tracks)
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    var plays = 0;
    var completions = 0;
    var listeningMs = 0;
    for (final track in tracks) {
      final item = history[track.id];
      plays += item?.playCount ?? 0;
      completions += item?.completedPlayCount ?? 0;
      listeningMs += item?.totalListenDurationMs ?? 0;
    }
    return ArtistProfile(
      name: artist,
      tracks: tracks,
      popularTracks: orderedByPopularity.take(10).toList(growable: false),
      recentlyPlayedTracks: orderedByRecent.where((track) => history.containsKey(track.id)).take(10).toList(growable: false),
      latestAdditions: orderedByAdded.take(10).toList(growable: false),
      albums: albumSet.toList()..sort(),
      similarArtists: _similarArtists(artist, tracks, library),
      listeningDurationMs: listeningMs,
      playCount: plays,
      completionRate: plays == 0 ? 0 : completions / plays,
    );
  }

  List<String> _similarArtists(String artist, List<Track> artistTracks, List<Track> library) {
    final genres = artistTracks.map((track) => track.genre).whereType<String>().where((genre) => genre.isNotEmpty).toSet();
    if (genres.isEmpty) return const [];
    final shared = <String, int>{};
    for (final track in library) {
      if (track.artist == artist || !genres.contains(track.genre)) continue;
      shared[track.artist] = (shared[track.artist] ?? 0) + 1;
    }
    final names = shared.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return names.take(5).map((item) => item.key).toList(growable: false);
  }
}
