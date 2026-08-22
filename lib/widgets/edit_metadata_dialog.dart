import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../models/metadata_override_model.dart';
import '../models/track_model.dart';
import '../providers/library_provider.dart';

class EditMetadataDialog extends ConsumerStatefulWidget {
  final Track track;

  const EditMetadataDialog({super.key, required this.track});

  @override
  ConsumerState<EditMetadataDialog> createState() => _EditMetadataDialogState();
}

class _EditMetadataDialogState extends ConsumerState<EditMetadataDialog> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _genreController;
  late TextEditingController _yearController;
  late TextEditingController _trackNumController;
  late TextEditingController _discNumController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.track.title);
    _artistController = TextEditingController(text: widget.track.artist);
    _albumController = TextEditingController(text: widget.track.album);
    _genreController = TextEditingController(text: widget.track.genre ?? '');
    _yearController = TextEditingController(text: widget.track.year?.toString() ?? '');
    _trackNumController = TextEditingController(text: widget.track.trackNumber?.toString() ?? '');
    _discNumController = TextEditingController(text: widget.track.discNumber?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    _trackNumController.dispose();
    _discNumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return AlertDialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Edit Track Metadata',
        style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'File: ${widget.track.filePath.split('/').last.split('\\').last}',
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            _buildTextField(_titleController, 'Title'),
            const SizedBox(height: 8),
            _buildTextField(_artistController, 'Artist'),
            const SizedBox(height: 8),
            _buildTextField(_albumController, 'Album'),
            const SizedBox(height: 8),
            _buildTextField(_genreController, 'Genre'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildTextField(_yearController, 'Year', isNumber: true)),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField(_trackNumController, 'Track #', isNumber: true)),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField(_discNumController, 'Disc #', isNumber: true)),
              ],
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
            backgroundColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () async {
            final override = MetadataOverride(
              trackId: widget.track.id,
              title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
              artist: _artistController.text.trim().isNotEmpty ? _artistController.text.trim() : null,
              album: _albumController.text.trim().isNotEmpty ? _albumController.text.trim() : null,
              genre: _genreController.text.trim().isNotEmpty ? _genreController.text.trim() : null,
              year: int.tryParse(_yearController.text.trim()),
              trackNumber: int.tryParse(_trackNumController.text.trim()),
              discNumber: int.tryParse(_discNumController.text.trim()),
              updatedAt: DateTime.now(),
            );

            await ref.read(libraryProvider.notifier).applyMetadataOverride(override);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Metadata updated! Search index refreshed.')),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
