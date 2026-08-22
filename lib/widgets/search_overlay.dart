import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class SearchOverlay extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onClose;
  final TextEditingController searchController;
  final Function(String) onChanged;

  const SearchOverlay({
    super.key,
    required this.isExpanded,
    required this.onClose,
    required this.searchController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) return const SizedBox.shrink();
    
    final isDark = AppColors.isDark(context);

    return Positioned(
      top: 16,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface(context).withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                color: isDark ? AppColors.darkAccent : AppColors.buttonBlack, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: searchController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Search playlists, songs...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: onChanged,
              ),
            ),
            if (searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear_rounded, color: AppColors.textSecondary(context)),
                onPressed: () {
                  searchController.clear();
                  onChanged('');
                },
              ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.textPrimary(context)),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
