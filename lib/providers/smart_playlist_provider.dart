import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/smart_playlist_rule_model.dart';
import '../models/track_model.dart';
import '../services/smart_playlist_builder_service.dart';
import '../services/storage_service.dart';
import 'audio_provider.dart';
import 'library_provider.dart';
import 'playlist_provider.dart';

class SmartPlaylistNotifier extends StateNotifier<List<SmartPlaylistDefinition>> {
  SmartPlaylistNotifier() : super(StorageService.getSmartPlaylistDefinitions());

  Future<void> save(SmartPlaylistDefinition definition) async {
    await StorageService.saveSmartPlaylistDefinition(definition);
    state = StorageService.getSmartPlaylistDefinitions();
  }

  Future<void> remove(String id) async {
    await StorageService.deleteSmartPlaylistDefinition(id);
    state = StorageService.getSmartPlaylistDefinitions();
  }
}

final smartPlaylistBuilderServiceProvider =
    Provider<SmartPlaylistBuilderService>((ref) => const SmartPlaylistBuilderService());

final smartPlaylistProvider =
    StateNotifierProvider<SmartPlaylistNotifier, List<SmartPlaylistDefinition>>((ref) {
  return SmartPlaylistNotifier();
});

final smartPlaylistTracksProvider = Provider.family<List<Track>, SmartPlaylistDefinition>((ref, definition) {
  final tracks = ref.watch(libraryProvider).tracks;
  final history = ref.watch(historyServiceProvider).historyMap;
  final playlists = ref.watch(playlistProvider).playlists;
  final favorites = ref.watch(playlistProvider).favoriteTrackIds;
  return ref.watch(smartPlaylistBuilderServiceProvider).evaluate(
        definition: definition,
        tracks: tracks,
        history: history,
        favoriteTrackIds: favorites,
        playlists: playlists,
      );
});
