import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../providers/audio_provider.dart';

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
              // Mini circular vinyl icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkAccent : AppColors.primaryText,
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
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
