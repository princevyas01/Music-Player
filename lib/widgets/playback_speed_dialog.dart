import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/audio_provider.dart';

class PlaybackSpeedDialog extends ConsumerStatefulWidget {
  const PlaybackSpeedDialog({super.key});

  @override
  ConsumerState<PlaybackSpeedDialog> createState() => _PlaybackSpeedDialogState();
}

class _PlaybackSpeedDialogState extends ConsumerState<PlaybackSpeedDialog> {
  late double _currentSpeed;

  @override
  void initState() {
    super.initState();
    _currentSpeed = ref.read(audioProvider).playbackSpeed;
  }

  void _updateSpeed(double val) {
    final normalized = (val * 100).round() / 100;
    final clamped = normalized.clamp(0.50, 2.00);
    setState(() {
      _currentSpeed = clamped;
    });
    ref.read(audioProvider.notifier).setPlaybackSpeed(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final presets = [0.50, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00];

    return AlertDialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Playback Speed',
            style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkAccent : AppColors.buttonBlack).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentSpeed.toStringAsFixed(2)}x',
              style: TextStyle(
                color: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Slider with fine controls
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: AppColors.textPrimary(context),
                  onPressed: _currentSpeed > 0.50 ? () => _updateSpeed(_currentSpeed - 0.05) : null,
                ),
                Expanded(
                  child: Slider(
                    value: _currentSpeed,
                    min: 0.50,
                    max: 2.00,
                    divisions: 30, // 0.05 increments
                    activeColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                    inactiveColor: AppColors.divider(context),
                    label: '${_currentSpeed.toStringAsFixed(2)}x',
                    onChanged: (val) => _updateSpeed(val),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: AppColors.textPrimary(context),
                  onPressed: _currentSpeed < 2.00 ? () => _updateSpeed(_currentSpeed + 0.05) : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Quick preset chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((speed) {
                final isSelected = (_currentSpeed - speed).abs() < 0.01;
                return ChoiceChip(
                  label: Text('${speed.toStringAsFixed(2)}x'),
                  selected: isSelected,
                  selectedColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary(context),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) => _updateSpeed(speed),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Reset button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary(context),
                side: BorderSide(color: AppColors.divider(context)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => _updateSpeed(1.00),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset to 1.00x'),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
