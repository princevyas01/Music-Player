import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/audio_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/smart_mix_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onExploreTap;

  const HomeScreen({super.key, required this.onExploreTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  final List<String> _catFaces = [
    '(ฅ^•ﻌ•^ฅ)',
    '(=^･ω･^=)',
    '(^>ω<^)',
    '(=^･ｪ･^=)',
    '( ฅ ฅ )',
    '(=①ω①=)',
  ];
  int _currentFaceIndex = 0;
  late AnimationController _tickController;
  int _lastFaceSwitchMs = 0;
  int _lastDanceMode = -1;

  @override
  void initState() {
    super.initState();
    // Free-running ticker at display refresh rate (120fps on 120Hz displays)
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _tickController.dispose();
    super.dispose();
  }

  void _cycleFace() {
    setState(() {
      _currentFaceIndex = (_currentFaceIndex + 1) % _catFaces.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = ref.watch(audioProvider.select((s) => s.isPlaying));
    final currentTrack = ref.watch(audioProvider.select((s) => s.currentTrack));
    final isDark = AppColors.isDark(context);
    final libraryState = ref.watch(libraryProvider);
    final hasTracks = libraryState.tracks.isNotEmpty;



    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Companion',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface(context),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.08),
                          width: 1.5,
                        ),
                        boxShadow: AppColors.softShadow(context),
                      ),
                      child: IconButton(
                        icon: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: AppColors.textPrimary(context),
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Speech Bubble and Cat Companion
              SizedBox(
                height: 400,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (currentTrack != null)
                      Positioned(
                        top: 20,
                        child: _SpeechBubble(
                          title: currentTrack.title,
                          artist: currentTrack.artist,
                          isPlaying: isPlaying,
                          onPlayPause: () {
                            ref.read(audioProvider.notifier).togglePlayPause();
                          },
                          onSkip: () => ref.read(audioProvider.notifier).next(),
                        ),
                      ),
                    
                    if (isPlaying)
                      Positioned.fill(
                        child: TickerMode(
                          enabled: isPlaying && TickerMode.of(context),
                          child: const _ParticleStream(),
                        ),
                      ),

                    Positioned(
                      bottom: 80,
                      child: GestureDetector(
                        onTap: _cycleFace,
                        child: AnimatedBuilder(
                          animation: _tickController,
                          builder: (context, child) {
                            final isTickerActive = isPlaying && TickerMode.of(context);
                            if (!isTickerActive && _tickController.isAnimating) {
                              _tickController.stop();
                            } else if (isTickerActive && !_tickController.isAnimating) {
                              _tickController.repeat();
                            }

                            final posMs = ref.read(audioProvider).position.inMilliseconds;
                            final now = DateTime.now().millisecondsSinceEpoch;
                            final t = isPlaying ? now.toDouble() : 0.0;
                            final danceMode = isPlaying ? ((posMs ~/ 5000) % 6) : -1;
                            
                            // Auto-cycle face when dance mode changes
                            if (danceMode != _lastDanceMode && danceMode >= 0) {
                              _lastDanceMode = danceMode;
                              if (now - _lastFaceSwitchMs > 3000) {
                                _lastFaceSwitchMs = now;
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    setState(() {
                                      _currentFaceIndex = (_currentFaceIndex + 1) % _catFaces.length;
                                    });
                                  }
                                });
                              }
                            }
                            
                            double bobY = 0.0;
                            double swayX = 0.0;
                            double tilt = 0.0;
                            double scale = 1.0;

                            if (isPlaying) {
                              switch (danceMode) {
                                case 0: // Gentle head-nod bounce
                                  bobY = sin(t / 350.0) * -8.0;
                                  tilt = cos(t / 700.0) * 0.06;
                                  break;
                                case 1: // Side-to-side sway (like grooving)
                                  swayX = sin(t / 400.0) * 20.0;
                                  bobY = sin(t / 800.0) * -4.0;
                                  tilt = sin(t / 400.0) * -0.12;
                                  break;
                                case 2: // Energetic hop (bouncy jump)
                                  bobY = -(sin(t / 180.0).abs()) * 22.0;
                                  scale = 1.0 + (sin(t / 180.0).abs()) * 0.04;
                                  break;
                                case 3: // Slow dramatic lean (ballad sway)
                                  tilt = sin(t / 900.0) * 0.18;
                                  swayX = cos(t / 900.0) * 12.0;
                                  bobY = sin(t / 1200.0) * -3.0;
                                  break;
                                case 4: // Double-tap pulse (heartbeat throb)
                                  final beatPhase = (t % 800.0) / 800.0;
                                  if (beatPhase < 0.1) {
                                    scale = 1.12;
                                  } else if (beatPhase > 0.25 && beatPhase < 0.35) {
                                    scale = 1.08;
                                  } else {
                                    scale = 1.0;
                                  }
                                  bobY = scale > 1.02 ? -6.0 : 0.0;
                                  break;
                                case 5: // Wild headbang (rock out)
                                  bobY = sin(t / 130.0) * -16.0;
                                  tilt = cos(t / 130.0) * 0.2;
                                  swayX = sin(t / 260.0) * 8.0;
                                  break;
                              }
                            }
                            
                            return Transform(
                              transform: Matrix4.translationValues(swayX, bobY, 0)
                                ..rotateZ(tilt)
                                ..scale(scale),
                              alignment: Alignment.center,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF1B1B26) : Colors.white,
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    if (isPlaying)
                                      BoxShadow(
                                        color: AppColors.accent.withOpacity(0.4),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _catFaces[_currentFaceIndex],
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  children: [
                    if (hasTracks) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.darkAccent : AppColors.buttonBlack,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize: const Size(double.infinity, 54),
                        ),
                        onPressed: () {
                          final randomIndex = Random().nextInt(libraryState.tracks.length);
                          ref.read(audioProvider.notifier).playTrackList(libraryState.tracks, randomIndex);
                        },
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Play Random Track', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF2A2A3C) : const Color(0xFFE5E2EC),
                          foregroundColor: AppColors.textPrimary(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          minimumSize: const Size(double.infinity, 54),
                        ),
                        onPressed: () {
                          final historyService = ref.read(historyServiceProvider);
                          final mix = ref.read(smartMixServiceProvider(historyService)).generateMix(libraryState.tracks);
                          if (mix.isNotEmpty) {
                            ref.read(audioProvider.notifier).playTrackList(mix, 0);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Playing Smart Mix (${mix.length} tracks)')),
                            );
                          }
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
                        label: const Text('Play Smart Mix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary(context),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        minimumSize: const Size(double.infinity, 54),
                      ),
                      onPressed: () {
                        if (!hasTracks) {
                          ref.read(libraryProvider.notifier).scanLibrary(forceRescan: true);
                        } else {
                          widget.onExploreTap();
                        }
                      },
                      child: Text(
                        hasTracks ? 'Explore Music' : 'Scan Library',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Ensures buttons never sit under the floating mini-player (which is hidden anyway, but just in case)
                    const SizedBox(height: 150),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String title;
  final String artist;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSkip;

  const _SpeechBubble({
    required this.title,
    required this.artist,
    this.isPlaying = false,
    required this.onPlayPause,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final accentColor = isDark ? AppColors.darkAccent : AppColors.buttonBlack;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main bubble
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          width: 260,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [AppColors.surface(context), const Color(0xFF1E1E2E)]
                  : [Colors.white, const Color(0xFFF5F5FA)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: accentColor.withOpacity(0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                artist,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      size: 36,
                      color: accentColor,
                    ),
                    onPressed: onPlayPause,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded, size: 32, color: AppColors.textSecondary(context)),
                    onPressed: onSkip,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Connector tail — blends bubble into the cat
        CustomPaint(
          size: const Size(20, 14),
          painter: _BubbleTailPainter(
            color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF5F5FA),
            borderColor: accentColor.withOpacity(0.25),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  _BubbleTailPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParticleStream extends StatefulWidget {
  const _ParticleStream();

  @override
  _ParticleStreamState createState() => _ParticleStreamState();
}

class _ParticleStreamState extends State<_ParticleStream> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<String> _notes = ['♪', '♫', '♬', '♩', '🎵'];
  final List<Color> _colors = [
    const Color(0xFFFF6B6B), const Color(0xFF6C5CE7), const Color(0xFF00CEC9),
    const Color(0xFFFDCB6E), const Color(0xFFE84393), const Color(0xFF74B9FF),
  ];
  final Random _random = Random();
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _particles = List.generate(16, (index) {
      return _Particle(
        note: _notes[_random.nextInt(_notes.length)],
        offset: _random.nextDouble(),
        speed: 0.4 + _random.nextDouble() * 0.8,
        xShift: _random.nextDouble() * 140 - 70,
        color: _colors[_random.nextInt(_colors.length)],
        size: 16.0 + _random.nextDouble() * 6.0,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTickerActive = TickerMode.of(context);
    if (!isTickerActive && _controller.isAnimating) {
      _controller.stop();
    } else if (isTickerActive && !_controller.isAnimating) {
      _controller.repeat();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final screenW = MediaQuery.of(context).size.width;
        return Stack(
          children: _particles.map((p) {
            final progress = (_controller.value * p.speed + p.offset) % 1.0;
            final yPos = 320 - (progress * 320);
            final xPos = (screenW / 2) + p.xShift + sin(progress * pi * 3) * 25;
            final opacity = sin(progress * pi).clamp(0.0, 0.85);

            return Positioned(
              left: xPos,
              top: yPos,
              child: Opacity(
                opacity: opacity,
                child: Text(
                  p.note,
                  style: TextStyle(
                    fontSize: p.size,
                    color: p.color,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Particle {
  final String note;
  final double offset;
  final double speed;
  final double xShift;
  final Color color;
  final double size;
  _Particle({required this.note, required this.offset, required this.speed, required this.xShift, required this.color, required this.size});
}


