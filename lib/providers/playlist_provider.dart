import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist_model.dart';
import '../models/playlist_folder_model.dart';
import '../models/track_model.dart';
import '../services/storage_service.dart';

enum PlaylistTrackSort { title, artist, album, dateAdded, duration }

class PlaylistState {
  final List<Playlist> playlists;
  final Set<String> favoriteTrackIds;
  final List<PlaylistFolder> folders;

  PlaylistState({
    required this.playlists,
    required this.favoriteTrackIds,
    this.folders = const [],
  });

  PlaylistState copyWith({
    List<Playlist>? playlists,
    Set<String>? favoriteTrackIds,
    List<PlaylistFolder>? folders,
  }) {
    return PlaylistState(
      playlists: playlists ?? this.playlists,
      favoriteTrackIds: favoriteTrackIds ?? this.favoriteTrackIds,
      folders: folders ?? this.folders,
    );
  }
}

class PlaylistNotifier extends StateNotifier<PlaylistState> {
  PlaylistNotifier()
      : super(PlaylistState(playlists: [], favoriteTrackIds: {}, folders: const [])) {
    loadData();
  }

  void loadData() {
    final playlists = StorageService.getPlaylists();
    final favorites = StorageService.getFavoriteTrackIds();
    final folders = StorageService.getPlaylistFolders();
    state = PlaylistState(
      playlists: playlists,
      favoriteTrackIds: favorites,
      folders: folders,
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

  Future<void> moveTrackInPlaylist(String playlistId, int fromIndex, int toIndex) async {
    final playlist = state.playlists.firstWhere((p) => p.id == playlistId);
    if (fromIndex < 0 || toIndex < 0 || fromIndex >= playlist.trackIds.length || toIndex >= playlist.trackIds.length) return;
    final ids = List<String>.from(playlist.trackIds);
    final id = ids.removeAt(fromIndex);
    ids.insert(toIndex, id);
    await _saveUpdatedPlaylist(playlist.copyWith(trackIds: ids));
  }

  Future<void> reversePlaylist(String playlistId) async {
    final playlist = state.playlists.firstWhere((p) => p.id == playlistId);
    await _saveUpdatedPlaylist(playlist.copyWith(trackIds: playlist.trackIds.reversed.toList()));
  }

  Future<void> shufflePlaylist(String playlistId, {int? seed}) async {
    final playlist = state.playlists.firstWhere((p) => p.id == playlistId);
    final ids = List<String>.from(playlist.trackIds)..shuffle(seed == null ? Random() : Random(seed));
    await _saveUpdatedPlaylist(playlist.copyWith(trackIds: ids));
  }

  Future<void> sortPlaylist(
    String playlistId,
    List<Track> library,
    PlaylistTrackSort sort,
  ) async {
    final playlist = state.playlists.firstWhere((p) => p.id == playlistId);
    final tracks = {for (final track in library) track.id: track};
    final ids = List<String>.from(playlist.trackIds);
    ids.sort((a, b) {
      final left = tracks[a];
      final right = tracks[b];
      if (left == null || right == null) return a.compareTo(b);
      switch (sort) {
        case PlaylistTrackSort.title:
          return left.title.compareTo(right.title);
        case PlaylistTrackSort.artist:
          return left.artist.compareTo(right.artist);
        case PlaylistTrackSort.album:
          return left.album.compareTo(right.album);
        case PlaylistTrackSort.dateAdded:
          return right.dateAdded.compareTo(left.dateAdded);
        case PlaylistTrackSort.duration:
          return left.durationMs.compareTo(right.durationMs);
      }
    });
    await _saveUpdatedPlaylist(playlist.copyWith(trackIds: ids, sortMode: sort.name));
  }

  Future<Playlist?> duplicatePlaylist(String playlistId, {String? name}) async {
    final source = state.playlists.firstWhere((p) => p.id == playlistId);
    final now = DateTime.now();
    final duplicate = Playlist(
      id: const Uuid().v4(),
      name: name?.trim().isNotEmpty == true ? name!.trim() : '${source.name} Copy',
      trackIds: List<String>.from(source.trackIds),
      createdAt: now,
      description: source.description,
      coverArt: source.coverArt,
      updatedAt: now,
      sortMode: source.sortMode,
      folderId: source.folderId,
    );
    await StorageService.savePlaylist(duplicate);
    loadData();
    return duplicate;
  }

  Future<void> mergePlaylists(String targetPlaylistId, String sourcePlaylistId) async {
    if (targetPlaylistId == sourcePlaylistId) return;
    final target = state.playlists.firstWhere((p) => p.id == targetPlaylistId);
    final source = state.playlists.firstWhere((p) => p.id == sourcePlaylistId);
    final merged = <String>{...target.trackIds, ...source.trackIds}.toList(growable: false);
    await _saveUpdatedPlaylist(target.copyWith(trackIds: merged));
  }

  Future<void> removeDuplicateTracks(String playlistId) async {
    final playlist = state.playlists.firstWhere((p) => p.id == playlistId);
    await _saveUpdatedPlaylist(playlist.copyWith(trackIds: playlist.trackIds.toSet().toList()));
  }

  Future<void> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await StorageService.savePlaylistFolder(PlaylistFolder(
      id: const Uuid().v4(),
      name: trimmed,
      playlistIds: const [],
      createdAt: DateTime.now(),
    ));
    loadData();
  }

  Future<void> movePlaylistToFolder(String playlistId, String? folderId) async {
    final playlist = state.playlists.firstWhere((p) => p.id == playlistId);
    await _saveUpdatedPlaylist(playlist.copyWith(
      folderId: folderId,
      clearFolder: folderId == null,
    ));
  }

  Future<void> _saveUpdatedPlaylist(Playlist playlist) async {
    await StorageService.savePlaylist(playlist.copyWith(updatedAt: DateTime.now()));
    loadData();
  }

  bool isFavorite(String trackId) {
    return state.favoriteTrackIds.contains(trackId);
  }
}

final playlistProvider = StateNotifierProvider<PlaylistNotifier, PlaylistState>((ref) {
  return PlaylistNotifier();
});
