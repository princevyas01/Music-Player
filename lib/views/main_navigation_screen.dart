import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/mini_player.dart';
import 'explore/explore_screen.dart';
import 'home/home_screen.dart';
import 'library/library_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 1; // Default to Explore tab
  bool _queueRestored = false;

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);

    // Restore saved persistent queue when library tracks arrive
    if (!_queueRestored && libraryState.tracks.isNotEmpty) {
      _queueRestored = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(audioProvider.notifier).restorePersistentQueue(libraryState.tracks);
      });
    }

    final List<Widget> screens = [
      HomeScreen(
        onExploreTap: () {
          setState(() {
            _currentIndex = 1;
          });
        },
      ),
      const ExploreScreen(),
      const LibraryScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Stack(
        children: [
          // Full-height main screens
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),

          // Floating Overlapping Bottom Playback & Navigation Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                AppBottomNav(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
