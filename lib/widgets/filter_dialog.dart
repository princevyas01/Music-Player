import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/library_provider.dart';

class FilterDialog extends ConsumerWidget {
  const FilterDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final isDark = AppColors.isDark(context);

    // Extract available genres and years
    final Set<String> genres = {};
    final Set<int> years = {};

    for (var t in libraryState.tracks) {
      if (t.genre != null && t.genre!.trim().isNotEmpty) {
        genres.add(t.genre!.trim());
      }
      if (t.year != null && t.year! > 0) {
        years.add(t.year!);
      }
    }

    final sortedGenres = genres.toList()..sort();
    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));

    return AlertDialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Filter Library',
            style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold),
          ),
          if (libraryState.selectedGenreFilter != null || libraryState.selectedYearFilter != null)
            TextButton(
              onPressed: () {
                ref.read(libraryProvider.notifier).setGenreFilter(null);
                ref.read(libraryProvider.notifier).setYearFilter(null);
                Navigator.pop(context);
              },
              child: const Text('Clear Filters'),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Genre Section
            Text('Filter by Genre:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context), fontSize: 14)),
            const SizedBox(height: 8),
            if (sortedGenres.isEmpty)
              Text('No genres found in library.', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedGenres.map((genre) {
                  final isSel = libraryState.selectedGenreFilter == genre;
                  return ChoiceChip(
                    label: Text(genre),
                    selected: isSel,
                    selectedColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                    labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary(context), fontSize: 12),
                    onSelected: (val) {
                      ref.read(libraryProvider.notifier).setGenreFilter(val ? genre : null);
                    },
                  );
                }).toList(),
              ),

            const SizedBox(height: 16),

            // Year Section
            Text('Filter by Year:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context), fontSize: 14)),
            const SizedBox(height: 8),
            if (sortedYears.isEmpty)
              Text('No release years found in library.', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedYears.map((yr) {
                  final isSel = libraryState.selectedYearFilter == yr;
                  return ChoiceChip(
                    label: Text('$yr'),
                    selected: isSel,
                    selectedColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                    labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary(context), fontSize: 12),
                    onSelected: (val) {
                      ref.read(libraryProvider.notifier).setYearFilter(val ? yr : null);
                    },
                  );
                }).toList(),
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
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
