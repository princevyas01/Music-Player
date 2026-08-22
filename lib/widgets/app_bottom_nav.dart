import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Bottom navigation bar matching reference design with Light/Dark mode support:
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      height: 60,
      margin: const EdgeInsets.fromLTRB(48, 4, 48, 20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppColors.softShadow(context),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(context, 0, Icons.home_outlined, Icons.home_rounded),
          _buildNavItem(context, 1, Icons.album_outlined, Icons.album_rounded),
          _buildNavItem(context, 2, Icons.bookmark_border_rounded, Icons.bookmark_rounded),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData inactiveIcon, IconData activeIcon) {
    final isSelected = currentIndex == index;
    final isDark = AppColors.isDark(context);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              key: ValueKey(isSelected),
              color: isSelected 
                  ? (isDark ? AppColors.darkAccent : AppColors.primaryText) 
                  : AppColors.divider(context),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
