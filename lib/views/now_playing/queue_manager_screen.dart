import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/queue_provider.dart';

/// Secondary queue surface. It leaves the Now Playing layout untouched while
/// exposing native playlist operations through the existing visual language.
class QueueManagerScreen extends ConsumerWidget {
  const QueueManagerScreen({super.key});

  Future<void> _saveQueue(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface(dialogContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Save Queue as Playlist',
          style: TextStyle(
            color: AppColors.textPrimary(dialogContext),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary(dialogContext)),
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) return;
    final playlist = await ref.read(queueServiceProvider).saveAsPlaylist(result);
    if (context.mounted && playlist != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "${playlist.name}"')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);
    final queueNotifier = ref.read(queueProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
        title: Text(
          'Queue',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Save queue as playlist',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: queue.items.isEmpty ? null : () => _saveQueue(context, ref),
          ),
          IconButton(
            tooltip: 'Clear upcoming tracks',
            icon: const Icon(Icons.playlist_remove_rounded),
            onPressed: queue.upcoming.isEmpty
                ? null
                : () async {
                    await queueNotifier.clearUpcoming();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Upcoming queue cleared')),
                      );
                    }
                  },
          ),
        ],
      ),
      body: queue.items.isEmpty
          ? Center(
              child: Text(
                'Your queue is empty',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: queue.items.length,
              onReorder: (oldIndex, newIndex) async {
                final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
                await queueNotifier.move(oldIndex, target);
              },
              itemBuilder: (context, index) {
                final item = queue.items[index];
                final isCurrent = index == queue.currentIndex;
                return Container(
                  key: ValueKey(item.queueId),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: isCurrent
                        ? Border.all(
                            color: AppColors.isDark(context)
                                ? AppColors.darkAccent
                                : AppColors.buttonBlack,
                          )
                        : null,
                  ),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: Icon(Icons.drag_handle_rounded,
                          color: AppColors.textSecondary(context)),
                    ),
                    title: Text(
                      item.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      isCurrent ? 'Now playing · ${item.track.artist}' : item.track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                    trailing: IconButton(
                      tooltip: isCurrent ? 'Current track cannot be removed' : 'Remove',
                      icon: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: isCurrent ? AppColors.divider(context) : Colors.redAccent,
                      ),
                      onPressed: isCurrent
                          ? null
                          : () async {
                              await queueNotifier.removeAt(index);
                            },
                    ),
                    onTap: () => queueNotifier.playAt(index),
                  ),
                );
              },
            ),
    );
  }
}
