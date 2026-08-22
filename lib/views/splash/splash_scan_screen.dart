import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/library_provider.dart';

class SplashScanScreen extends ConsumerStatefulWidget {
  const SplashScanScreen({super.key});

  @override
  ConsumerState<SplashScanScreen> createState() => _SplashScanScreenState();
}

class _SplashScanScreenState extends ConsumerState<SplashScanScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndStartScan();
  }

  Future<void> _checkAndStartScan() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    await ref.read(libraryProvider.notifier).scanLibrary();

    if (mounted) {
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.softShadow(),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.album_rounded,
                      size: 54,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'VibeFlow',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 32,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Offline & Synced Music Haven',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 48),

                // Rationale & scanning progress card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppColors.softShadow(),
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        libraryState.isLoading
                            ? 'Indexing your local audio library...'
                            : 'Library Ready! Loading...',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scanning device storage for local tracks.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
