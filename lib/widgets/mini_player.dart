import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../providers/audio_provider.dart';

import 'vinyl_disc_widget.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(audioProvider.select((s) => s.currentTrack));
    final isPlaying = ref.watch(audioProvider.select((s) => s.isPlaying));
    final isDark = AppColors.isDark(context);

    if (track == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: () {
          context.push('/now-playing');
        },
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(32),
            boxShadow: AppColors.softShadow(context),
            border: isDark ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
          ),
          child: Row(
            children: [
              // Mini circular vinyl icon with custom photo support
              VinylDiscWidget(
                size: 44,
                title: track.title,
                artist: track.artist,
                artworkUri: track.artworkUri,
                trackId: track.id,
                filePath: track.filePath,
                seed: int.tryParse(track.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
              ),
              const SizedBox(width: 12),
              // Track Info
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Play/Pause button
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppColors.textPrimary(context),
                  size: 28,
                ),
                onPressed: () {
                  ref.read(audioProvider.notifier).togglePlayPause();
                },
              ),
              // Next button
              IconButton(
                icon: Icon(
                  Icons.skip_next_rounded,
                  color: AppColors.textPrimary(context),
                  size: 24,
                ),
                onPressed: () {
                  ref.read(audioProvider.notifier).next();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
