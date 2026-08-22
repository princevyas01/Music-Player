import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../providers/playlist_provider.dart';

class CreatePlaylistDialog extends ConsumerStatefulWidget {
  const CreatePlaylistDialog({super.key});

  @override
  ConsumerState<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends ConsumerState<CreatePlaylistDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'New Playlist',
        style: TextStyle(
          color: AppColors.primaryText,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: AppColors.primaryText),
        decoration: InputDecoration(
          hintText: 'Playlist name',
          hintStyle: TextStyle(color: AppColors.secondaryText.withOpacity(0.5)),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.accent),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.dividerInactive),
          ),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            ref.read(playlistProvider.notifier).createPlaylist(value.trim());
            context.pop();
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
        ),
        TextButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              ref.read(playlistProvider.notifier).createPlaylist(_controller.text.trim());
              context.pop();
            }
          },
          child: const Text('Create', style: TextStyle(color: AppColors.accent)),
        ),
      ],
    );
  }
}
