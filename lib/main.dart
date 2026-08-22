import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/audio_player_handler.dart';
import 'services/storage_service.dart';
import 'providers/theme_provider.dart';

/// Global reference to the audio handler initialized via AudioService.
/// This ensures a single instance is shared across Riverpod providers.
late AudioPlayerHandler globalAudioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive boxes for local storage
  await StorageService.init();

  // Initialize audio_service with our custom handler.
  // This creates the Android foreground service, media session,
  // and notification channel for lock-screen / notification controls.
  globalAudioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.spinwave.music_player.channel.audio',
      androidNotificationChannelName: 'SpinWave Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  runApp(
    const ProviderScope(
      child: SpinWaveApp(),
    ),
  );
}


class SpinWaveApp extends ConsumerWidget {
  const SpinWaveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'SpinWave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
