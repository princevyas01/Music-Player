import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/track_model.dart';
import '../../providers/audio_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/vinyl_disc_widget.dart';
import '../../widgets/search_overlay.dart';
import '../../widgets/filter_dialog.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _scrollPosition = ValueNotifier(0.0);
  late AnimationController _springController;
  double _scrollVelocity = 0.0;
  
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _springController = AnimationController.unbounded(vsync: this);
    _springController.addListener(() {
      _scrollPosition.value = _springController.value;
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    _scrollPosition.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _springController.stop();
    _scrollPosition.value -= details.delta.dy * 1.2;
  }

  void _onPanEnd(DragEndDetails details, int itemCount) {
    _scrollVelocity = -details.velocity.pixelsPerSecond.dy;
    
    // Calculate bounds
    const itemHeight = 120.0;
    final double maxScroll = (itemCount - 1) * itemHeight;
    
    // Simulate physics with a much looser, less sticky spring
    const spring = SpringDescription(mass: 0.6, stiffness: 150.0, damping: 16.0);
    
    // Target snap - let it coast more with higher velocity multiplier
    double target = _scrollPosition.value + (_scrollVelocity * 0.2);
    target = (target / itemHeight).round() * itemHeight;
    target = target.clamp(0.0, maxScroll);
    
    final simulation = SpringSimulation(
      spring,
      _scrollPosition.value,
      target,
      _scrollVelocity * 0.4,
    );
    
    _springController.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final playingTrackId = ref.watch(audioProvider.select((s) => s.currentTrack?.id));
    final isDark = AppColors.isDark(context);
    
    // Use filteredTracks if searching, else use all tracks
    final tracks = libraryState.searchQuery.isNotEmpty 
        ? libraryState.filteredTracks 
        : libraryState.tracks;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        bottom: false, // Don't clip at bottom so wheel goes under nav
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Rotary Wheel
            if (libraryState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (tracks.isEmpty)
              Center(
                child: Text(
                  'No tracks found.',
                  style: TextStyle(color: AppColors.textSecondary(context)),
                ),
              )
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _onPanUpdate,
                onVerticalDragEnd: (details) => _onPanEnd(details, tracks.length),
                child: SizedBox.expand(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrollPosition,
                    builder: (context, scrollPos, _) {
                      const itemHeight = 120.0;
                      final baseCenterY = MediaQuery.of(context).size.height / 2 - 100;
                      
                      final int centerIndex = (scrollPos / itemHeight).round();
                      final int startIndex = max(0, centerIndex - 6);
                      final int endIndex = min(tracks.length - 1, centerIndex + 6);

                      final visibleIndices = <int>[];
                      for (int i = startIndex; i <= endIndex; i++) {
                        visibleIndices.add(i);
                      }

                      return Stack(
                        clipBehavior: Clip.none,
                        children: visibleIndices.map((index) {
                          final currentY = (index * itemHeight) - scrollPos;
                          final relativeIndex = currentY / itemHeight;
                          
                          // Parabolic curve math
                          final xOffset = pow(relativeIndex.abs(), 1.7) * 40.0 + 20.0;
                          
                          final track = tracks[index];
                          final isPlaying = playingTrackId == track.id;
                          final isCenter = relativeIndex.abs() < 0.5;
                          
                          return Positioned(
                            left: xOffset,
                            top: baseCenterY + currentY,
                            child: _RotaryTrackItem(
                              track: track,
                              isPlaying: isPlaying,
                              isCenter: isCenter,
                              relativeIndex: relativeIndex,
                              onTap: () {
                                if (!isCenter) {
                                  // Snap to this item if tapped
                                  final target = index * itemHeight;
                                  const spring = SpringDescription(mass: 0.8, stiffness: 220.0, damping: 22.0);
                                  final simulation = SpringSimulation(spring, _scrollPosition.value, target, 0);
                                  _springController.animateWith(simulation);
                                }
                                // Play it immediately whether centered or not
                                ref.read(audioProvider.notifier).playTrackList(tracks, index);
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),

            // Header Controls (floating above wheel)
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title Badge
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
                      'Explore',
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
                      // Theme Toggle
                      _buildCircularHeaderBtn(
                        context,
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        () => ref.read(themeProvider.notifier).toggleTheme(),
                      ),
                      const SizedBox(width: 8),
                      // Search Toggle
                      _buildCircularHeaderBtn(
                        context,
                        Icons.search_rounded,
                        () {
                          setState(() {
                            _isSearchExpanded = true;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      // Settings / Refresh menu
                      _buildMenuBtn(context),
                    ],
                  ),
                ],
              ),
            ),
            
            // Search Overlay
            SearchOverlay(
              isExpanded: _isSearchExpanded,
              searchController: _searchController,
              onClose: () {
                setState(() {
                  _isSearchExpanded = false;
                  _searchController.clear();
                  ref.read(libraryProvider.notifier).setSearchQuery('');
                });
              },
              onChanged: (val) {
                ref.read(libraryProvider.notifier).setSearchQuery(val);
                // Reset scroll to top when searching
                _scrollPosition.value = 0.0;
                _springController.stop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularHeaderBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    final isDark = AppColors.isDark(context);
    return Container(
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
      child: IconButton(
        icon: Icon(icon, color: AppColors.textPrimary(context), size: 22),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }
  
  Widget _buildMenuBtn(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
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
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_horiz, color: AppColors.textPrimary(context)),
        color: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        padding: EdgeInsets.zero,
        onSelected: (value) {
          final notifier = ref.read(libraryProvider.notifier);
          switch (value) {
            case 'refresh':
              notifier.scanLibrary(forceRescan: true);
              break;
            case 'filter':
              showDialog(context: context, builder: (context) => const FilterDialog());
              break;
            case 'sort_date':
              notifier.setSortOption(TrackSortOption.dateAdded);
              break;
            case 'sort_artist':
              notifier.setSortOption(TrackSortOption.artist);
              break;
            case 'sort_title':
              notifier.setSortOption(TrackSortOption.title);
              break;
            case 'settings':
              context.push('/settings');
              break;
          }
        },
        itemBuilder: (context) {
          final textStyle = TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600);
          final libraryState = ref.watch(libraryProvider);
          final hasActiveFilter = libraryState.selectedGenreFilter != null || libraryState.selectedYearFilter != null;
          return [
            PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh, color: AppColors.textPrimary(context), size: 20), const SizedBox(width: 12), Text('Refresh Library', style: textStyle)])),
            PopupMenuItem(value: 'filter', child: Row(children: [Icon(hasActiveFilter ? Icons.filter_alt_rounded : Icons.filter_alt_outlined, color: hasActiveFilter ? AppColors.accent : AppColors.textPrimary(context), size: 20), const SizedBox(width: 12), Text(hasActiveFilter ? 'Filter (Active)' : 'Filter Genre / Year', style: textStyle)])),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'sort_date', child: Row(children: [Icon(libraryState.sortOption == TrackSortOption.dateAdded ? Icons.check : Icons.circle_outlined, color: AppColors.textPrimary(context), size: 20), const SizedBox(width: 12), Text('Sort by Date Added', style: textStyle)])),
            PopupMenuItem(value: 'sort_artist', child: Row(children: [Icon(libraryState.sortOption == TrackSortOption.artist ? Icons.check : Icons.circle_outlined, color: AppColors.textPrimary(context), size: 20), const SizedBox(width: 12), Text('Sort by Artist', style: textStyle)])),
            PopupMenuItem(value: 'sort_title', child: Row(children: [Icon(libraryState.sortOption == TrackSortOption.title ? Icons.check : Icons.circle_outlined, color: AppColors.textPrimary(context), size: 20), const SizedBox(width: 12), Text('Sort by Title', style: textStyle)])),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings, color: AppColors.textPrimary(context), size: 20), const SizedBox(width: 12), Text('Settings', style: textStyle)])),
          ];
        },
      ),
    );
  }
}

class _RotaryTrackItem extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final bool isCenter;
  final double relativeIndex;
  final VoidCallback onTap;

  const _RotaryTrackItem({
    required this.track,
    required this.isPlaying,
    required this.isCenter,
    required this.relativeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rotationAngle = relativeIndex * 0.15;
    
    final thumbnail = VinylDiscWidget(
      size: isCenter ? 70 : 64,
      title: track.title,
      seed: int.parse(track.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(1, '0')) % 100,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        width: MediaQuery.of(context).size.width - 32, // Match screen width bounds
        child: isCenter
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: AppColors.softShadow(context),
                  border: Border.all(
                    color: AppColors.textPrimary(context).withOpacity(0.05),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    thumbnail,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                              fontFamily: 'Poppins',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            track.artist,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        return IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: AppColors.textPrimary(context),
                            size: 32,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              ref.read(audioProvider.notifier).togglePlayPause();
                            } else {
                              onTap();
                            }
                          },
                        );
                      }
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        return IconButton(
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: AppColors.textPrimary(context),
                            size: 28,
                          ),
                          onPressed: () {
                            ref.read(audioProvider.notifier).next();
                          },
                        );
                      }
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  thumbnail,
                  const SizedBox(width: 16),
                  Transform(
                    transform: Matrix4.rotationZ(rotationAngle),
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.artist,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
