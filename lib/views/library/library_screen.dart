import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/track_model.dart';
import '../../providers/audio_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/smart_playlist_service.dart';
import '../../services/smart_mix_service.dart';
import '../../widgets/add_to_playlist_dialog.dart';
import '../../widgets/vinyl_disc_widget.dart';
import '../../widgets/create_playlist_dialog.dart';
import '../../widgets/filter_dialog.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _selectedFilterIndex = 0; // 0: Playlists, 1: Favorites, 2: Vinyl Collection

  // Search state
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final playlistState = ref.watch(playlistProvider);
    final isDark = AppColors.isDark(context);

    // Use unified search state
    final tracks = libraryState.searchQuery.isNotEmpty 
        ? libraryState.filteredTracks 
        : libraryState.tracks;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.08),
                            width: 1.5,
                          ),
                          boxShadow: AppColors.softShadow(context),
                        ),
                        child: Text(
                          'Library',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // Genre / Year Filter Button
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (libraryState.selectedGenreFilter != null || libraryState.selectedYearFilter != null)
                                  ? (isDark ? AppColors.darkAccent : AppColors.buttonBlack)
                                  : AppColors.surface(context),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.08),
                                width: 1.5,
                              ),
                              boxShadow: AppColors.softShadow(context),
                            ),
                            child: Center(
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Filter Library',
                                icon: Icon(
                                  Icons.filter_alt_rounded,
                                  color: (libraryState.selectedGenreFilter != null || libraryState.selectedYearFilter != null)
                                      ? Colors.white
                                      : AppColors.textPrimary(context),
                                  size: 20,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => const FilterDialog(),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Search Icon Badge Button
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isSearchExpanded
                                  ? (isDark ? AppColors.darkAccent : AppColors.buttonBlack)
                                  : AppColors.surface(context),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.08),
                                width: 1.5,
                              ),
                              boxShadow: AppColors.softShadow(context),
                            ),
                            child: Center(
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Search Library',
                                icon: Icon(
                                  _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
                                  color: _isSearchExpanded ? Colors.white : AppColors.textPrimary(context),
                                  size: 22,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSearchExpanded = !_isSearchExpanded;
                                    if (!_isSearchExpanded) {
                                      _searchController.clear();
                                      ref.read(libraryProvider.notifier).setSearchQuery('');
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Create Playlist Button
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface(context),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.08),
                                width: 1.5,
                              ),
                              boxShadow: AppColors.softShadow(context),
                            ),
                            child: Center(
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.add_rounded, size: 26, color: AppColors.textPrimary(context)),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => const CreatePlaylistDialog(),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Filter Pills Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterPill(0, 'Playlists (${playlistState.playlists.length})'),
                      const SizedBox(width: 10),
                      _buildFilterPill(1, 'Favorites (${playlistState.favoriteTrackIds.length})'),
                      const SizedBox(width: 10),
                      _buildFilterPill(2, 'Vinyl Collection (${tracks.length})'),
                      const SizedBox(width: 10),
                      _buildFilterPill(3, 'Smart Playlists & Mix'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Body Content based on active filter tab
                Expanded(
                  child: _selectedFilterIndex == 0
                      ? _buildPlaylistsTab(playlistState, tracks, libraryState)
                      : _selectedFilterIndex == 1
                          ? _buildFavoritesTab(playlistState, tracks, libraryState)
                          : _selectedFilterIndex == 2
                              ? _buildVinylCollectionGrid(tracks, libraryState)
                              : _buildSmartPlaylistsTab(tracks),
                ),
              ],
            ),

            // GLASSMORPHIC BLUR OVERLAY & ENLARGED SEARCH BAR
            if (_isSearchExpanded)
              Positioned.fill(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSearchExpanded = false;
                        });
                      },
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          color: (isDark ? Colors.black : Colors.white).withOpacity(0.25),
                        ),
                      ),
                    ),

                    Positioned(
                      top: 16,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context).withOpacity(0.90),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded,
                                color: isDark ? AppColors.darkAccent : AppColors.buttonBlack, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search playlists, songs...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) {
                                  ref.read(libraryProvider.notifier).setSearchQuery(val);
                                },
                              ),
                            ),
                            if (libraryState.searchQuery.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.clear_rounded, color: AppColors.textSecondary(context)),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(libraryProvider.notifier).setSearchQuery('');
                                },
                              ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: AppColors.textPrimary(context)),
                              onPressed: () {
                                setState(() {
                                  _isSearchExpanded = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    final isDark = AppColors.isDark(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? AppColors.darkAccent : AppColors.buttonBlack) 
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected ? AppColors.softShadow(context) : [],
          border: (!isSelected && isDark) ? Border.all(color: Colors.white12) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary(context),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistsTab(PlaylistState state, List<Track> allTracks, LibraryState libraryState) {
    final rawPlaylists = state.playlists;
    final playlists = libraryState.searchQuery.isEmpty
        ? rawPlaylists
        : rawPlaylists.where((p) => p.name.toLowerCase().startsWith(libraryState.searchQuery.toLowerCase())).toList();

    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music_rounded, size: 56, color: AppColors.divider(context)),
            const SizedBox(height: 16),
            Text(
              libraryState.searchQuery.isNotEmpty ? 'No Matching Playlists' : 'No Custom Playlists',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
            ),
            const SizedBox(height: 8),
            Text(
              libraryState.searchQuery.isNotEmpty
                  ? 'Try searching for a different playlist name.'
                  : 'Create a playlist to organize your favorite vinyl tracks.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const CreatePlaylistDialog(),
                );
              },
              child: const Text('Create Playlist'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, left: 24, right: 24),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return GestureDetector(
          onTap: () {
            context.push('/playlist-details', extra: playlist.id);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppColors.softShadow(context),
            ),
            child: Row(
              children: [
                VinylDiscWidget(size: 54, title: playlist.name, seed: index),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${playlist.trackIds.length} Tracks • Tap to Open Stream',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppColors.textSecondary(context)),
                  onPressed: () {
                    context.push('/playlist-details', extra: playlist.id);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary(context)),
                  onPressed: () {
                    ref.read(playlistProvider.notifier).deletePlaylist(playlist.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab(PlaylistState state, List<Track> tracks, LibraryState libraryState) {
    final filteredFavs = tracks.where((t) => state.favoriteTrackIds.contains(t.id)).toList();

    if (filteredFavs.isEmpty) {
      return Center(
        child: Text(
          libraryState.searchQuery.isNotEmpty
              ? 'No matching favorite tracks found.'
              : 'No favorite tracks added yet.\nTap ❤ on any track in Explore!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, left: 24, right: 24),
      itemCount: filteredFavs.length,
      itemBuilder: (context, index) {
        final track = filteredFavs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.softShadow(context),
          ),
          child: Row(
            children: [
              VinylDiscWidget(size: 50, title: track.title, seed: index),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      track.artist,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.playlist_add_rounded, color: AppColors.textSecondary(context)),
                onPressed: () => showAddToPlaylistSheet(context, ref, track),
              ),
              IconButton(
                icon: Icon(Icons.play_circle_fill_rounded, size: 36, color: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack),
                onPressed: () {
                  ref.read(audioProvider.notifier).playTrackList(filteredFavs, index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVinylCollectionGrid(List<Track> tracks, LibraryState libraryState) {

    if (tracks.isEmpty) {
      return Center(
        child: Text(
          libraryState.searchQuery.isNotEmpty ? 'No matching vinyl records found' : 'No vinyl records in storage',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 120, left: 24, right: 24, top: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.82,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return GestureDetector(
          onTap: () {
            ref.read(audioProvider.notifier).playTrackList(tracks, index);
          },
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: VinylDiscWidget(
                  size: 110,
                  title: track.title,
                  seed: index,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 12,
                top: 24,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.softShadow(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.album_rounded, color: AppColors.accent, size: 28),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.playlist_add_rounded, size: 22, color: AppColors.textSecondary(context)),
                            onPressed: () => showAddToPlaylistSheet(context, ref, track),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmartPlaylistsTab(List<Track> allTracks) {
    final historyService = ref.watch(historyServiceProvider);
    final smartService = SmartPlaylistService(historyService);
    final smartMixService = SmartMixService(historyService);

    final smartPlaylists = [
      {'name': 'Recently Added', 'tracks': smartService.getRecentlyAdded(allTracks), 'icon': Icons.new_releases_rounded, 'desc': 'Newest additions to library'},
      {'name': 'Recently Played', 'tracks': smartService.getRecentlyPlayed(allTracks), 'icon': Icons.history_rounded, 'desc': 'Tracks played recently'},
      {'name': 'Most Played', 'tracks': smartService.getMostPlayed(allTracks), 'icon': Icons.equalizer_rounded, 'desc': 'Your top played tracks'},
      {'name': 'Favorites', 'tracks': smartService.getFavorites(allTracks), 'icon': Icons.favorite_rounded, 'desc': 'Loved vinyl tracks'},
      {'name': 'Never Played', 'tracks': smartService.getNeverPlayed(allTracks), 'icon': Icons.explore_outlined, 'desc': 'Unheard tracks in collection'},
      {'name': 'Frequently Played', 'tracks': smartService.getFrequentlyPlayed(allTracks), 'icon': Icons.repeat_rounded, 'desc': 'Listened to 3+ times'},
      {'name': 'Forgotten Songs', 'tracks': smartService.getForgottenSongs(allTracks), 'icon': Icons.bedtime_rounded, 'desc': 'Played before, unplayed in 60 days'},
      {'name': 'Short Tracks', 'tracks': smartService.getShortTracks(allTracks), 'icon': Icons.timer_10_rounded, 'desc': 'Tracks under 2 minutes'},
      {'name': 'Long Tracks', 'tracks': smartService.getLongTracks(allTracks), 'icon': Icons.straighten_rounded, 'desc': 'Tracks over 5 minutes'},
      {'name': 'Recently Completed', 'tracks': smartService.getRecentlyCompleted(allTracks), 'icon': Icons.task_alt_rounded, 'desc': 'Full track listens'},
    ];

    final isDark = AppColors.isDark(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 120, left: 24, right: 24),
      children: [
        // Smart Mix Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF6C5CE7).withOpacity(0.3), const Color(0xFF181822)]
                  : [const Color(0xFFE7B8B0).withOpacity(0.4), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            boxShadow: AppColors.softShadow(context),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 38, color: AppColors.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Mix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                    const SizedBox(height: 2),
                    Text('Local offline recommendation algorithm based on history & recency', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  final mix = smartMixService.generateMix(allTracks);
                  if (mix.isNotEmpty) {
                    ref.read(audioProvider.notifier).playTrackList(mix, 0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Playing Smart Mix (${mix.length} tracks)')),
                    );
                  }
                },
                child: const Text('Play Mix'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('10 Dynamic Smart Playlists', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
        const SizedBox(height: 12),
        ...smartPlaylists.map((sp) {
          final name = sp['name'] as String;
          final spTracks = sp['tracks'] as List<Track>;
          final icon = sp['icon'] as IconData;
          final desc = sp['desc'] as String;

          return GestureDetector(
            onTap: () => _showSmartPlaylistSheet(context, name, spTracks),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.softShadow(context),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDark ? AppColors.darkAccent : AppColors.buttonBlack).withOpacity(0.12),
                    ),
                    child: Icon(icon, color: isDark ? AppColors.darkAccent : AppColors.buttonBlack, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                        const SizedBox(height: 2),
                        Text('${spTracks.length} Tracks • $desc', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.play_circle_fill_rounded, size: 34, color: isDark ? AppColors.darkAccent : AppColors.buttonBlack),
                    onPressed: spTracks.isNotEmpty
                        ? () => ref.read(audioProvider.notifier).playTrackList(spTracks, 0)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showSmartPlaylistSheet(BuildContext context, String title, List<Track> tracks) {
    final isDark = AppColors.isDark(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider(context), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                          Text('${tracks.length} Tracks', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                        ],
                      ),
                      if (tracks.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            ref.read(audioProvider.notifier).playTrackList(tracks, 0);
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play All'),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: tracks.isEmpty
                        ? Center(child: Text('No tracks in this smart playlist.', style: TextStyle(color: AppColors.textSecondary(context))))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: tracks.length,
                            itemBuilder: (context, index) {
                              final track = tracks[index];
                              return ListTile(
                                leading: VinylDiscWidget(size: 42, title: track.title, seed: index),
                                title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                                subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                                onTap: () {
                                  Navigator.pop(context);
                                  ref.read(audioProvider.notifier).playTrackList(tracks, index);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
