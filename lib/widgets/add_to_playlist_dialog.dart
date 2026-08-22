import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../models/track_model.dart';
import '../providers/playlist_provider.dart';
import 'create_playlist_dialog.dart';

/// Shows a bottom sheet allowing the user to select which playlist(s) to add [track] to.
void showAddToPlaylistSheet(BuildContext context, WidgetRef ref, Track track) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final playlistState = ref.watch(playlistProvider);
          final playlists = playlistState.playlists;
          final isDark = AppColors.isDark(context);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add to Playlist',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.textPrimary(context)),
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => const CreatePlaylistDialog(),
                        );
                      },
                    ),
                  ],
                ),
                Text(
                  'Track: "${track.title}"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 16),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'No playlists yet',
                            style: TextStyle(color: AppColors.textSecondary(context)),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (context) => const CreatePlaylistDialog(),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create New Playlist'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final inPlaylist = playlist.trackIds.contains(track.id);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            inPlaylist ? Icons.playlist_add_check_rounded : Icons.playlist_add_rounded,
                            color: inPlaylist ? AppColors.darkAccent : AppColors.textSecondary(context),
                            size: 28,
                          ),
                          title: Text(
                            playlist.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          subtitle: Text(
                            '${playlist.trackIds.length} tracks',
                            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                          ),
                          trailing: Icon(
                            inPlaylist ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                            color: inPlaylist ? AppColors.darkAccent : AppColors.divider(context),
                          ),
                          onTap: () {
                            if (inPlaylist) {
                              ref.read(playlistProvider.notifier).removeTrackFromPlaylist(playlist.id, track.id);
                            } else {
                              ref.read(playlistProvider.notifier).addTrackToPlaylist(playlist.id, track.id);
                            }
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(inPlaylist
                                    ? 'Removed from "${playlist.name}"'
                                    : 'Added to "${playlist.name}"'),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
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
