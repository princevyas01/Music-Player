import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme/app_colors.dart';
import '../models/metadata_override_model.dart';
import '../models/track_model.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../services/smart_crop_service.dart';
import 'vinyl_disc_widget.dart';

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

  String? _currentArtworkUri;
  bool _artworkChanged = false;
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
    _currentArtworkUri = widget.track.artworkUri;
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

  Future<void> _pickAndCropPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (picked == null) return;

      setState(() => _isCropping = true);
      final bytes = await picked.readAsBytes();
      final croppedPath = await SmartCropService.processAndSaveArtwork(
        imageBytes: bytes,
        trackId: widget.track.id,
      );

      if (mounted) {
        setState(() {
          _isCropping = false;
          if (croppedPath != null) {
            _currentArtworkUri = croppedPath;
            _artworkChanged = true;
          }
        });
        if (croppedPath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not process image.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting photo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final hasCustomPhoto = _currentArtworkUri != null && _currentArtworkUri!.isNotEmpty;

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
            // Circular Artwork Editor Section
            Center(
              child: GestureDetector(
                onTap: _isCropping ? null : _pickAndCropPhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: AppColors.softShadow(context),
                      ),
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VinylDiscWidget(
                              size: 90,
                              title: widget.track.title,
                              artist: widget.track.artist,
                              artworkUri: _currentArtworkUri,
                              seed: int.tryParse(widget.track.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                            ),
                            if (_isCropping)
                              Container(
                                color: Colors.black45,
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Camera / Edit badge
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                        border: Border.all(color: AppColors.surface(context), width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _isCropping ? null : _pickAndCropPhoto,
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: Text(
                    hasCustomPhoto ? 'Change Photo' : 'Add Photo',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (hasCustomPhoto) ...[
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentArtworkUri = '';
                        _artworkChanged = true;
                      });
                    },
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent.withOpacity(0.85),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
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
              artworkUri: _artworkChanged ? _currentArtworkUri : widget.track.artworkUri,
              updatedAt: DateTime.now(),
            );

            await ref.read(libraryProvider.notifier).applyMetadataOverride(
              override,
              onTrackUpdated: (updated) {
                ref.read(audioProvider.notifier).updateTrackMetadata(updated);
              },
            );

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Song photo and metadata saved!')),
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
