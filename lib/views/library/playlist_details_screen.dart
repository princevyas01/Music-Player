import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/playlist_model.dart';
import '../../models/track_model.dart';
import '../../providers/audio_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/backup_restore_service.dart';
import '../../widgets/vinyl_disc_widget.dart';

class PlaylistDetailsScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistDetailsScreen({
    super.key,
    required this.playlistId,
  });

  @override
  ConsumerState<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends ConsumerState<PlaylistDetailsScreen> with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _scrollPosition = ValueNotifier(0.0);
  late AnimationController _springController;
  double _scrollVelocity = 0.0;

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
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _springController.stop();
    _scrollPosition.value -= details.delta.dy * 1.2;
  }

  void _onPanEnd(DragEndDetails details, int itemCount) {
    _scrollVelocity = -details.velocity.pixelsPerSecond.dy;
    
    const itemHeight = 120.0;
    final double maxScroll = (itemCount - 1) * itemHeight;
    
    const spring = SpringDescription(mass: 0.6, stiffness: 150.0, damping: 16.0);
    
    double target = _scrollPosition.value + (_scrollVelocity * 0.2);
    target = (target / itemHeight).round() * itemHeight;
    target = target.clamp(0.0, maxScroll);
    
    final simulation = SpringSimulation(spring, _scrollPosition.value, target, _scrollVelocity * 0.4);
    _springController.animateWith(simulation);
  }

  void _showAddSongsPicker(BuildContext context, Playlist playlist, List<Track> allTracks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                final currentPlaylist = ref.watch(playlistProvider).playlists
                    .firstWhere((p) => p.id == playlist.id, orElse: () => playlist);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Songs to "${playlist.name}"',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: allTracks.length,
                          itemBuilder: (context, index) {
                            final track = allTracks[index];
                            final inPlaylist = currentPlaylist.trackIds.contains(track.id);

                            return CheckboxListTile(
                              value: inPlaylist,
                              activeColor: AppColors.darkAccent,
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                              ),
                              secondary: VinylDiscWidget(
                                size: 40, 
                                title: track.title, 
                                seed: int.parse(track.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(1, '0')) % 100
                              ),
                              onChanged: (bool? checked) {
                                if (checked == true) {
                                  ref.read(playlistProvider.notifier).addTrackToPlaylist(playlist.id, track.id);
                                } else {
                                  ref.read(playlistProvider.notifier).removeTrackFromPlaylist(playlist.id, track.id);
                                }
                                setSheetState(() {});
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final playlistState = ref.watch(playlistProvider);
    final audioState = ref.watch(audioProvider);
    final isDark = AppColors.isDark(context);

    final playlists = playlistState.playlists;
    final playlist = playlists.firstWhere(
      (p) => p.id == widget.playlistId,
      orElse: () => Playlist(id: widget.playlistId, name: 'Playlist', trackIds: [], createdAt: DateTime.now()),
    );

    final allTracks = libraryState.tracks;
    final playlistTracks = allTracks.where((t) => playlist.trackIds.contains(t.id)).toList();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary(context)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          playlist.name,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 24),
            tooltip: 'Export M3U Playlist',
            onPressed: () {
              final m3u = BackupRestoreService.exportPlaylistM3u(playlist, allTracks);
              Clipboard.setData(ClipboardData(text: m3u));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('M3U playlist "${playlist.name}" copied to Clipboard!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add_rounded, size: 28),
            tooltip: 'Add Songs',
            onPressed: () => _showAddSongsPicker(context, playlist, allTracks),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playlist Sub-header Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${playlistTracks.length} Songs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const Spacer(),
                  if (playlistTracks.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        ref.read(audioProvider.notifier).playTrackList(playlistTracks, 0);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Play All'),
                    ),
                ],
              ),
            ),

            // Rotary Circular Arc Wheel Carousel for Playlist Songs
            Expanded(
              child: playlistTracks.isEmpty
                  ? _buildEmptyPlaylist(context, playlist, allTracks)
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: _onPanUpdate,
                      onVerticalDragEnd: (details) => _onPanEnd(details, playlistTracks.length),
                      child: SizedBox.expand(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _scrollPosition,
                          builder: (context, scrollPos, _) {
                            const itemHeight = 120.0;
                            final baseCenterY = MediaQuery.of(context).size.height / 2 - 160;
                            
                            final int centerIndex = (scrollPos / itemHeight).round();
                            final int startIndex = max(0, centerIndex - 6);
                            final int endIndex = min(playlistTracks.length - 1, centerIndex + 6);

                            final visibleIndices = <int>[];
                            for (int i = startIndex; i <= endIndex; i++) {
                              visibleIndices.add(i);
                            }

                            return Stack(
                              clipBehavior: Clip.none,
                              children: visibleIndices.map((index) {
                                final currentY = (index * itemHeight) - scrollPos;
                                final relativeIndex = currentY / itemHeight;
                                
                                final xOffset = pow(relativeIndex.abs(), 1.7) * 40.0 + 20.0;
                                
                                final track = playlistTracks[index];
                                final isPlaying = audioState.currentTrack?.id == track.id;
                                final isCenter = relativeIndex.abs() < 0.5;
                                
                                return Positioned(
                                  left: xOffset,
                                  top: baseCenterY + currentY,
                                  child: _RotaryTrackItem(
                                    track: track,
                                    isPlaying: isPlaying,
                                    isCenter: isCenter,
                                    relativeIndex: relativeIndex,
                                    onRemove: () {
                                      ref.read(playlistProvider.notifier).removeTrackFromPlaylist(playlist.id, track.id);
                                    },
                                    onTap: () {
                                      if (!isCenter) {
                                        final target = index * itemHeight;
                                        const spring = SpringDescription(mass: 0.8, stiffness: 220.0, damping: 22.0);
                                        final simulation = SpringSimulation(spring, _scrollPosition.value, target, 0);
                                        _springController.animateWith(simulation);
                                      }
                                      ref.read(audioProvider.notifier).playTrackList(playlistTracks, index);
                                    },
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlaylist(BuildContext context, Playlist playlist, List<Track> allTracks) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_play_rounded, size: 64, color: AppColors.divider(context)),
            const SizedBox(height: 16),
            Text(
              'Playlist is Empty',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context)),
            ),
            const SizedBox(height: 8),
            Text(
              'Add tracks to "${playlist.name}" to display them in the rotary circular arc stream.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => _showAddSongsPicker(context, playlist, allTracks),
              icon: const Icon(Icons.add),
              label: const Text('Add Songs Now'),
            ),
          ],
        ),
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
  final VoidCallback onRemove;

  const _RotaryTrackItem({
    required this.track,
    required this.isPlaying,
    required this.isCenter,
    required this.relativeIndex,
    required this.onTap,
    required this.onRemove,
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
        width: MediaQuery.of(context).size.width - 32,
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
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                      onPressed: onRemove,
                    ),
                    const SizedBox(width: 4),
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
