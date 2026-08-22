import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../services/music_stats_service.dart';

class MusicStatsDialog extends ConsumerWidget {
  const MusicStatsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final historyService = ref.watch(historyServiceProvider);
    final statsService = MusicStatsService(historyService);
    final stats = statsService.computeStats(libraryState.tracks);
    final isDark = AppColors.isDark(context);

    return AlertDialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Detailed Music Analytics',
        style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatTile(context, '${stats.totalTracks}', 'Tracks'),
                  _buildStatTile(context, '${stats.totalAlbums}', 'Albums'),
                  _buildStatTile(context, '${stats.totalArtists}', 'Artists'),
                  _buildStatTile(context, stats.formatDuration(stats.totalListenTimeMs), 'Total Time'),
                ],
              ),
              const Divider(height: 24),
              // Listening Trends Section
              Text('Listening Trends', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text('Past 7 Days', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                          const SizedBox(height: 2),
                          Text(stats.formatDuration(stats.weeklyListenTimeMs), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text('Past 30 Days', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                          const SizedBox(height: 2),
                          Text(stats.formatDuration(stats.monthlyListenTimeMs), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Top Tracks Section
              if (stats.topTracks.isNotEmpty) ...[
                Text('Top Played Tracks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                const SizedBox(height: 6),
                ...stats.topTracks.map((t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        children: [
                          Icon(Icons.music_note_rounded, size: 16, color: AppColors.textSecondary(context)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${t.title} • ${t.artist}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context))),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
              ],
              // Top Artists Section
              if (stats.topArtists.isNotEmpty) ...[
                Text('Top Artists', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                const SizedBox(height: 6),
                ...stats.topArtists.map((artist) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text('• $artist', style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context))),
                    )),
                const SizedBox(height: 16),
              ],
              // Top Albums Section
              if (stats.topAlbums.isNotEmpty) ...[
                Text('Top Albums', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                const SizedBox(height: 6),
                ...stats.topAlbums.map((album) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text('• $album', style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context))),
                    )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStatTile(BuildContext context, String val, String label) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context))),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
      ],
    );
  }
}
