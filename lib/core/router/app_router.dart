import 'package:go_router/go_router.dart';
import '../../views/library/playlist_details_screen.dart';
import '../../views/main_navigation_screen.dart';
import '../../views/now_playing/now_playing_screen.dart';
import '../../views/settings/settings_screen.dart';
import '../../views/splash/splash_scan_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScanScreen(),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) => const MainNavigationScreen(),
    ),
    GoRoute(
      path: '/now-playing',
      builder: (context, state) => const NowPlayingScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/playlist-details',
      builder: (context, state) {
        final playlistId = state.extra as String;
        return PlaylistDetailsScreen(playlistId: playlistId);
      },
    ),
  ],
);
