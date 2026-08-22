import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/backup_restore_service.dart';
import '../../services/library_audit_service.dart';
import '../../services/music_stats_service.dart';
import '../../widgets/playback_speed_dialog.dart';
import '../../widgets/music_stats_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showShortTrackFilterDialog(BuildContext context, WidgetRef ref) {
    final currentSec = ref.watch(libraryProvider).shortTrackThresholdSeconds;
    final options = [3, 5, 8, 10, 15];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Short-Track Filter',
            style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((sec) {
              return RadioListTile<int>(
                value: sec,
                groupValue: currentSec,
                activeColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                title: Text('$sec Seconds ${sec == 8 ? '(Default)' : ''}',
                    style: TextStyle(color: AppColors.textPrimary(context))),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(libraryProvider.notifier).setShortTrackThreshold(val);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showPlaybackSpeedDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const PlaybackSpeedDialog(),
    );
  }

  void _showSleepTimerDialog(BuildContext context, WidgetRef ref) {
    final currentMinutes = ref.watch(audioProvider.select((s) => s.sleepTimerMinutes));
    final currentFade = ref.watch(audioProvider.select((s) => s.sleepFadeOutSeconds));

    int selectedMin = currentMinutes;
    int selectedFade = currentFade;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.surface(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Sleep Timer & Fade-Out',
                style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Timer Duration:', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [0, 15, 30, 45, 60].map((min) {
                        final isSel = selectedMin == min;
                        return ChoiceChip(
                          label: Text(min == 0 ? 'Off' : '$min min'),
                          selected: isSel,
                          selectedColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                          labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary(context)),
                          onSelected: (val) => setState(() => selectedMin = min),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('Volume Fade-Out:', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [0, 10, 20, 30, 60].map((sec) {
                        final isSel = selectedFade == sec;
                        return ChoiceChip(
                          label: Text(sec == 0 ? 'Instant' : '$sec sec'),
                          selected: isSel,
                          selectedColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                          labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary(context)),
                          onSelected: (val) => setState(() => selectedFade = sec),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    ref.read(audioProvider.notifier).setSleepTimer(selectedMin, fadeOutSeconds: selectedFade);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _runCheckLibrary(BuildContext context, WidgetRef ref) async {
    final tracks = ref.read(libraryProvider).tracks;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final report = await LibraryAuditService.runAudit(tracks);
    if (context.mounted) {
      Navigator.pop(context); // Close loading indicator
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.surface(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Library Audit Report', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Broken / Missing Tracks: ${report.brokenTracks.length}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: report.brokenTracks.isEmpty ? Colors.green : Colors.redAccent)),
                  const SizedBox(height: 12),
                  Text('Duplicate Track Groups: ${report.duplicateGroups.length}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: report.duplicateGroups.isEmpty ? Colors.green : Colors.orangeAccent)),
                  if (report.brokenTracks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Missing Files:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ...report.brokenTracks.take(5).map((t) => Text('• ${t.title} (${t.artist})', style: const TextStyle(fontSize: 11))),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          );
        },
      );
    }
  }

  void _handleExportBackup(BuildContext context) {
    final backupJson = BackupRestoreService.exportFullBackup();
    Clipboard.setData(ClipboardData(text: backupJson));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SpinWave Backup copied to Clipboard!')),
    );
  }

  void _handleRestoreBackup(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Restore Backup', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paste your SpinWave JSON Backup below:', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 5,
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 12),
                decoration: InputDecoration(
                  hintText: '{"schemaVersion": 1, ...}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.isDark(context) ? AppColors.darkAccent : AppColors.buttonBlack,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                final success = await BackupRestoreService.restoreFullBackup(controller.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ref.read(libraryProvider.notifier).scanLibrary(forceRescan: false);
                    ref.read(playlistProvider.notifier).loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backup restored successfully!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid backup JSON format or version mismatch.')),
                    );
                  }
                }
              },
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final historyService = ref.watch(historyServiceProvider);
    final statsService = MusicStatsService(historyService);
    final stats = statsService.computeStats(libraryState.tracks);

    final speed = ref.watch(audioProvider.select((s) => s.playbackSpeed));
    final sleepMin = ref.watch(audioProvider.select((s) => s.sleepTimerMinutes));

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Settings', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary(context)),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Audio & Playback Preferences Card
          _buildCard(
            context,
            title: 'Playback & Audio Controls',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.speed_rounded, color: AppColors.textSecondary(context)),
                title: Text('Playback Speed', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                subtitle: Text('${speed}x speed • Pitch preserved', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary(context)),
                onTap: () => _showPlaybackSpeedDialog(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bedtime_rounded, color: AppColors.textSecondary(context)),
                title: Text('Sleep Timer & Fade-Out', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                subtitle: Text(sleepMin > 0 ? 'Active ($sleepMin min)' : 'Disabled', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary(context)),
                onTap: () => _showSleepTimerDialog(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.filter_list_rounded, color: AppColors.textSecondary(context)),
                title: Text('Short-Track Filter', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                subtitle: Text('Ignore audio shorter than ${libraryState.shortTrackThresholdSeconds}s', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary(context)),
                onTap: () => _showShortTrackFilterDialog(context, ref),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Library Maintenance Card
          _buildCard(
            context,
            title: 'Library Maintenance & Audit',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.health_and_safety_rounded, color: AppColors.textSecondary(context)),
                title: Text('Check Library', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                subtitle: Text('Scan for broken tracks and duplicate audio files', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary(context)),
                onTap: () => _runCheckLibrary(context, ref),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Backup & Restore Card
          _buildCard(
            context,
            title: 'Backup & Restore',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.upload_file_rounded, color: AppColors.textSecondary(context)),
                title: Text('Export SpinWave Backup', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                subtitle: Text('Copy offline favorites, playlists & settings JSON', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                onTap: () => _handleExportBackup(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.download_rounded, color: AppColors.textSecondary(context)),
                title: Text('Restore SpinWave Backup', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600)),
                subtitle: Text('Atomically restore data from JSON backup', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                onTap: () => _handleRestoreBackup(context, ref),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Music Statistics Card
          _buildCard(
            context,
            title: 'Listening Statistics',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(context, '${stats.totalTracks}', 'Tracks'),
                    _buildStatItem(context, '${stats.totalAlbums}', 'Albums'),
                    _buildStatItem(context, '${stats.totalArtists}', 'Artists'),
                    _buildStatItem(context, stats.formatDuration(stats.totalListenTimeMs), 'Listened'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const MusicStatsDialog(),
                    );
                  },
                  icon: const Icon(Icons.analytics_rounded, size: 18),
                  label: const Text('View Detailed Analytics & Trends'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // About Card
          _buildCard(
            context,
            title: 'About SpinWave',
            children: [
              Text(
                'SpinWave is a production-grade, lightweight, offline-first music player with rotary disc interaction and 120Hz companion animations.',
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Version', style: TextStyle(color: AppColors.textSecondary(context))),
                  Text('1.0.0+1 (Release)', style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required String title, required List<Widget> children}) {
    final isDark = AppColors.isDark(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
        boxShadow: AppColors.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String val, String label) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
      ],
    );
  }
}

