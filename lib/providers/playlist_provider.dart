import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist_model.dart';
import '../services/storage_service.dart';

class PlaylistState {
  final List<Playlist> playlists;
  final Set<String> favoriteTrackIds;

  PlaylistState({
    required this.playlists,
    required this.favoriteTrackIds,
  });

  PlaylistState copyWith({
    List<Playlist>? playlists,
    Set<String>? favoriteTrackIds,
  }) {
    return PlaylistState(
      playlists: playlists ?? this.playlists,
      favoriteTrackIds: favoriteTrackIds ?? this.favoriteTrackIds,
    );
  }
}

class PlaylistNotifier extends StateNotifier<PlaylistState> {
  PlaylistNotifier()
      : super(PlaylistState(playlists: [], favoriteTrackIds: {})) {
    loadData();
  }

  void loadData() {
    final playlists = StorageService.getPlaylists();
    final favorites = StorageService.getFavoriteTrackIds();
    state = PlaylistState(
      playlists: playlists,
      favoriteTrackIds: favorites,
    );
  }

  Future<void> createPlaylist(String name) async {
    if (name.trim().isEmpty) return;
    final playlist = Playlist(
      id: const Uuid().v4(),
      name: name.trim(),
      trackIds: [],
      createdAt: DateTime.now(),
    );
    await StorageService.savePlaylist(playlist);
    loadData();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await StorageService.deletePlaylist(playlistId);
    loadData();
  }

  Future<void> toggleFavorite(String trackId) async {
    await StorageService.toggleFavorite(trackId);
    loadData();
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final playlist = state.playlists.firstWhere((p) => p.id == playlistId);
    if (!playlist.trackIds.contains(trackId)) {
      final updated = playlist.copyWith(
        trackIds: [...playlist.trackIds, trackId],
      );
      await StorageService.savePlaylist(updated);
      loadData();
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final playlist = state.playlists.firstWhere((p) => p.id == playlistId);
    if (playlist.trackIds.contains(trackId)) {
      final updatedTrackIds = List<String>.from(playlist.trackIds)..remove(trackId);
      final updated = playlist.copyWith(
        trackIds: updatedTrackIds,
      );
      await StorageService.savePlaylist(updated);
      loadData();
    }
  }

  bool isFavorite(String trackId) {
    return state.favoriteTrackIds.contains(trackId);
  }
}

final playlistProvider = StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
  return PlaylistNotifier();
});
