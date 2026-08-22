import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/audio_player_handler.dart';
import '../../widgets/add_to_playlist_dialog.dart';
import '../../widgets/playback_speed_dialog.dart';
import '../../widgets/edit_metadata_dialog.dart';
import 'vinyl_player_widget.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showTrackOptionsMenu(BuildContext context, WidgetRef ref) {
    final track = ref.read(audioProvider).currentTrack;
    if (track == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final audioState = ref.watch(audioProvider);
            final isFav = ref.watch(playlistProvider).favoriteTrackIds.contains(track.id);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                  ),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    leading: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? Colors.redAccent : AppColors.textSecondary(context)),
                    title: Text(isFav ? 'Remove from Favorites' : 'Add to Favorites',
                        style: TextStyle(color: AppColors.textPrimary(context))),
                    onTap: () {
                      ref.read(playlistProvider.notifier).toggleFavorite(track.id);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.playlist_add_rounded, color: AppColors.textSecondary(context)),
                    title: Text('Add to Playlist', style: TextStyle(color: AppColors.textPrimary(context))),
                    onTap: () {
                      Navigator.pop(context);
                      showAddToPlaylistSheet(context, ref, track);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.edit_note_rounded, color: AppColors.textSecondary(context)),
                    title: Text('Edit Track Metadata', style: TextStyle(color: AppColors.textPrimary(context))),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => EditMetadataDialog(track: track),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.speed_rounded, color: AppColors.textSecondary(context)),
                    title: Text('Playback Speed (${audioState.playbackSpeed.toStringAsFixed(2)}x)', style: TextStyle(color: AppColors.textPrimary(context))),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => const PlaybackSpeedDialog(),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.timer_outlined, color: AppColors.textSecondary(context)),
                    title: Text(
                      audioState.stopMode == StopMode.none
                          ? 'Stop Mode: Off'
                          : 'Stop Mode: ${audioState.stopMode.name.replaceAll('afterCurrent', 'After ')}',
                      style: TextStyle(color: AppColors.textPrimary(context)),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showStopModePicker(context, ref);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStopModePicker(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(audioProvider).stopMode;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Stop Mode', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<StopMode>(
                value: StopMode.none,
                groupValue: currentMode,
                activeColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                title: Text('Off (Continuous Play)', style: TextStyle(color: AppColors.textPrimary(context))),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(audioProvider.notifier).setStopMode(val);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<StopMode>(
                value: StopMode.afterCurrentTrack,
                groupValue: currentMode,
                activeColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                title: Text('Stop after Current Track', style: TextStyle(color: AppColors.textPrimary(context))),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(audioProvider.notifier).setStopMode(val);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<StopMode>(
                value: StopMode.afterCurrentAlbum,
                groupValue: currentMode,
                activeColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                title: Text('Stop after Current Album', style: TextStyle(color: AppColors.textPrimary(context))),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(audioProvider.notifier).setStopMode(val);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<StopMode>(
                value: StopMode.afterCurrentQueue,
                groupValue: currentMode,
                activeColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                title: Text('Stop after Current Queue', style: TextStyle(color: AppColors.textPrimary(context))),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(audioProvider.notifier).setStopMode(val);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(audioProvider.select((s) => s.currentTrack));
    final isPlaying = ref.watch(audioProvider.select((s) => s.isPlaying));
    final position = ref.watch(audioProvider.select((s) => s.position));
    final duration = ref.watch(audioProvider.select((s) => s.duration));
    final isShuffle = ref.watch(audioProvider.select((s) => s.isShuffleEnabled));
    final loopMode = ref.watch(audioProvider.select((s) => s.loopMode));

    double progress = 0.0;
    if (duration.inMilliseconds > 0) {
      progress = (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    }

    if (track == null) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary(context)),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary(context)),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: AppColors.textPrimary(context)),
            onPressed: () => _showTrackOptionsMenu(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Vinyl Turntable
            Center(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: VinylPlayerWidget(
                  isPlaying: isPlaying,
                  size: 240,
                  progress: progress,
                  onSeek: (newProgress) {
                    final newMillis = (newProgress * duration.inMilliseconds).round();
                    ref.read(audioProvider.notifier).seek(Duration(milliseconds: newMillis));
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Track Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    track.artist,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Waveform Visualizer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(30, (index) {
                final heights = [
                  12, 16, 24, 20, 32, 40, 24, 16, 12, 36, 
                  44, 32, 28, 16, 20, 12, 28, 36, 16, 20, 
                  40, 28, 16, 12, 28, 32, 20, 16, 24, 12
                ];
                return Container(
                  width: 3,
                  height: heights[index % heights.length].toDouble(),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: AppColors.divider(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Time Display
            Text(
              '${_formatDuration(position)} / ${_formatDuration(duration)}',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
              ),
            ),
            const Spacer(),
            // Playback Controls Row (Shuffle, Prev, Play/Pause, Next, Repeat)
            Padding(
              padding: const EdgeInsets.only(bottom: 48.0, left: 24.0, right: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Shuffle Toggle
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: isShuffle ? (AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack) : AppColors.textSecondary(context),
                      size: 24,
                    ),
                    onPressed: () => ref.read(audioProvider.notifier).toggleShuffle(),
                  ),

                  // Previous
                  _OutlinedButton(
                    icon: Icons.skip_previous,
                    onTap: () => ref.read(audioProvider.notifier).previous(),
                  ),

                  // Play/Pause
                  GestureDetector(
                    onTap: () => ref.read(audioProvider.notifier).togglePlayPause(),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: AppColors.bg(context),
                        size: 32,
                      ),
                    ),
                  ),

                  // Next
                  _OutlinedButton(
                    icon: Icons.skip_next,
                    onTap: () => ref.read(audioProvider.notifier).next(),
                  ),

                  // Repeat Toggle
                  IconButton(
                    icon: Icon(
                      loopMode == LoopMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: loopMode != LoopMode.off ? (AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack) : AppColors.textSecondary(context),
                      size: 24,
                    ),
                    onPressed: () => ref.read(audioProvider.notifier).toggleRepeat(),
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

class _OutlinedButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _OutlinedButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.divider(context),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: AppColors.textPrimary(context),
          size: 28,
        ),
      ),
    );
  }
}
