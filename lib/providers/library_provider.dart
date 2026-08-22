import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track_model.dart';
import '../models/playlist_model.dart';
import '../models/metadata_override_model.dart';
import '../services/library_service.dart';
import '../services/storage_service.dart';
import '../services/search_index_service.dart';

enum TrackSortOption { dateAdded, title, artist, album, year }

// Preserved for legacy test compatibility
class TrieNode {
  final Map<String, TrieNode> children = {};
  final Set<Track> tracks = {};
}

class TrackTrie {
  final TrieNode _root = TrieNode();

  void insert(String key, Track track) {
    if (key.isEmpty) return;
    TrieNode current = _root;
    for (int i = 0; i < key.length; i++) {
      final char = key[i];
      current = current.children.putIfAbsent(char, () => TrieNode());
      current.tracks.add(track);
    }
  }

  void clear() {
    _root.children.clear();
    _root.tracks.clear();
  }

  Set<Track> searchPrefix(String prefix) {
    if (prefix.isEmpty) return {};
    TrieNode current = _root;
    for (int i = 0; i < prefix.length; i++) {
      final char = prefix[i];
      if (!current.children.containsKey(char)) {
        return {};
      }
      current = current.children[char]!;
    }
    return current.tracks;
  }
}

class LibraryState {
  final List<Track> tracks;
  final bool isLoading;
  final TrackSortOption sortOption;
  final String searchQuery;
  final List<Track> filteredTracks;
  final String? selectedGenreFilter;
  final int? selectedYearFilter;
  final int shortTrackThresholdSeconds;

  LibraryState({
    required this.tracks,
    required this.isLoading,
    this.sortOption = TrackSortOption.dateAdded,
    this.searchQuery = '',
    this.filteredTracks = const [],
    this.selectedGenreFilter,
    this.selectedYearFilter,
    this.shortTrackThresholdSeconds = 8,
  });

  LibraryState copyWith({
    List<Track>? tracks,
    bool? isLoading,
    TrackSortOption? sortOption,
    String? searchQuery,
    List<Track>? filteredTracks,
    String? selectedGenreFilter,
    int? selectedYearFilter,
    int? shortTrackThresholdSeconds,
    bool clearGenreFilter = false,
    bool clearYearFilter = false,
  }) {
    return LibraryState(
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      sortOption: sortOption ?? this.sortOption,
      searchQuery: searchQuery ?? this.searchQuery,
      filteredTracks: filteredTracks ?? this.filteredTracks,
      selectedGenreFilter: clearGenreFilter ? null : (selectedGenreFilter ?? this.selectedGenreFilter),
      selectedYearFilter: clearYearFilter ? null : (selectedYearFilter ?? this.selectedYearFilter),
      shortTrackThresholdSeconds: shortTrackThresholdSeconds ?? this.shortTrackThresholdSeconds,
    );
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  final LibraryService _libraryService;
  final SearchIndexService _searchIndex = SearchIndexService();
  bool _isScanning = false;

  LibraryNotifier(this._libraryService)
      : super(LibraryState(
          tracks: [],
          isLoading: true,
          sortOption: _parseSortOption(StorageService.getSortOption()),
          shortTrackThresholdSeconds: StorageService.getShortTrackThresholdSeconds(),
        )) {
    scanLibrary();
  }

  static TrackSortOption _parseSortOption(String val) {
    switch (val) {
      case 'title':
        return TrackSortOption.title;
      case 'artist':
        return TrackSortOption.artist;
      case 'album':
        return TrackSortOption.album;
      case 'year':
        return TrackSortOption.year;
      case 'dateAdded':
      default:
        return TrackSortOption.dateAdded;
    }
  }

  Future<void> scanLibrary({bool forceRescan = false, List<Playlist> playlists = const []}) async {
    if (_isScanning) return;
    _isScanning = true;

    try {
      state = state.copyWith(isLoading: true);
      final rawTracks = await _libraryService.queryDeviceTracks(forceRescan: forceRescan);

      final minMs = state.shortTrackThresholdSeconds * 1000;
      final tracks = rawTracks.where((t) => t.durationMs >= minMs).toList();

      // Build Search Index
      _searchIndex.buildIndex(tracks, playlists);

      final sorted = _sort(tracks, state.sortOption);
      state = state.copyWith(
        tracks: sorted,
        filteredTracks: _applyFiltersAndSearch(sorted, state.searchQuery),
        isLoading: false,
      );
    } finally {
      _isScanning = false;
    }
  }

  void rebuildSearchIndex(List<Playlist> playlists) {
    _searchIndex.buildIndex(state.tracks, playlists);
    state = state.copyWith(
      filteredTracks: _applyFiltersAndSearch(state.tracks, state.searchQuery),
    );
  }

  void setSearchQuery(String query) {
    if (query == state.searchQuery) return;
    state = state.copyWith(
      searchQuery: query,
      filteredTracks: _applyFiltersAndSearch(state.tracks, query),
    );
  }

  void setGenreFilter(String? genre) {
    if (genre == state.selectedGenreFilter) return;
    state = state.copyWith(
      selectedGenreFilter: genre,
      clearGenreFilter: genre == null,
      filteredTracks: _applyFiltersAndSearch(
        state.tracks,
        state.searchQuery,
        genreFilter: genre,
        yearFilter: state.selectedYearFilter,
      ),
    );
  }

  void setYearFilter(int? year) {
    if (year == state.selectedYearFilter) return;
    state = state.copyWith(
      selectedYearFilter: year,
      clearYearFilter: year == null,
      filteredTracks: _applyFiltersAndSearch(
        state.tracks,
        state.searchQuery,
        genreFilter: state.selectedGenreFilter,
        yearFilter: year,
      ),
    );
  }

  Future<void> setShortTrackThreshold(int seconds) async {
    await StorageService.setShortTrackThresholdSeconds(seconds);
    state = state.copyWith(shortTrackThresholdSeconds: seconds);
    await scanLibrary(forceRescan: false);
  }

  void setSortOption(TrackSortOption sortOption) {
    StorageService.setSortOption(sortOption.name);
    final sorted = _sort(state.tracks, sortOption);
    state = state.copyWith(
      sortOption: sortOption,
      tracks: sorted,
      filteredTracks: _applyFiltersAndSearch(sorted, state.searchQuery),
    );
  }

  Future<void> applyMetadataOverride(MetadataOverride override) async {
    await StorageService.saveMetadataOverride(override);
    await scanLibrary(forceRescan: false);
  }

  List<Track> _applyFiltersAndSearch(
    List<Track> allTracks,
    String query, {
    String? genreFilter,
    int? yearFilter,
  }) {
    final activeGenre = genreFilter ?? state.selectedGenreFilter;
    final activeYear = yearFilter ?? state.selectedYearFilter;

    var filtered = allTracks;
    if (activeGenre != null && activeGenre.isNotEmpty) {
      filtered = filtered.where((t) => (t.genre ?? 'Unknown Genre') == activeGenre).toList();
    }
    if (activeYear != null) {
      filtered = filtered.where((t) => t.year == activeYear).toList();
    }

    if (query.trim().isEmpty) {
      return filtered;
    }

    // Use ranked search index
    final searchResults = _searchIndex.search(query);
    if (activeGenre != null || activeYear != null) {
      final Set<String> validIds = filtered.map((t) => t.id).toSet();
      return searchResults.where((t) => validIds.contains(t.id)).toList();
    }
    return searchResults;
  }

  List<Track> _sort(List<Track> list, TrackSortOption option) {
    final sorted = List<Track>.from(list);
    switch (option) {
      case TrackSortOption.title:
        sorted.sort((a, b) => a.title.trim().toLowerCase().compareTo(b.title.trim().toLowerCase()));
        break;
      case TrackSortOption.artist:
        sorted.sort((a, b) => a.artist.trim().toLowerCase().compareTo(b.artist.trim().toLowerCase()));
        break;
      case TrackSortOption.album:
        sorted.sort((a, b) => a.album.trim().toLowerCase().compareTo(b.album.trim().toLowerCase()));
        break;
      case TrackSortOption.year:
        sorted.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        break;
      case TrackSortOption.dateAdded:
        sorted.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
    }
    return sorted;
  }
}

final libraryServiceProvider = Provider((ref) => LibraryService());

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  final service = ref.watch(libraryServiceProvider);
  return LibraryNotifier(service);
});
