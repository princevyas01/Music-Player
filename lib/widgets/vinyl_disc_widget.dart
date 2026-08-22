import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Renders a circular album artwork placeholder with varied styles
/// matching the exact reference image (text, gradients, abstracts) with theme support.
class VinylDiscWidget extends StatelessWidget {
  final double size;
  final String? title;
  final String? artist;
  final String? artworkUri;
  final int seed;

  const VinylDiscWidget({
    super.key,
    required this.size,
    this.title,
    this.artist,
    this.artworkUri,
    this.seed = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF1B1B26) : Colors.white,
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: artworkUri != null
            ? _buildArtworkImage()
            : _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildArtworkImage() {
    // Offline-safe: artwork URIs are never HTTP in an offline music player.
    // If artworkUri were set, it would be a local file path or content:// URI.
    // Currently artworkUri is always null (set to null in library_service.dart),
    // so this path is defensive only.
    return Builder(
      builder: (context) => _buildPlaceholder(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final type = (seed.abs() % 5);
    switch (type) {
      case 0:
        return _buildTypographyCover(context);
      case 1:
        return _buildAbstractGradient(context);
      case 2:
        return _buildDarkMonochrome(context);
      case 3:
        return _buildYellowAccent(context);
      case 4:
      default:
        return _buildMinimalistCircle(context);
    }
  }

  Widget _buildTypographyCover(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      color: isDark ? const Color(0xFF22222E) : Colors.white,
      child: Stack(
        children: [
          Positioned(
            left: -size * 0.2,
            top: -size * 0.1,
            child: Transform.rotate(
              angle: -0.2,
              child: Text(
                '10',
                style: TextStyle(
                  fontSize: size * 0.9,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFF3B3B4F) : const Color(0xFF222222),
                  letterSpacing: -5,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: size * 0.1,
            bottom: size * 0.2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: isDark ? AppColors.darkAccent : const Color(0xFF222222),
              child: const Text(
                'I\'M GOING BACK TO',
                style: TextStyle(
                  fontSize: 6,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbstractGradient(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2A2A38), const Color(0xFF181824), const Color(0xFF222232)]
              : [const Color(0xFFF0F0F0), const Color(0xFFD0D0D0), const Color(0xFFE8E8E8)],
        ),
      ),
      child: CustomPaint(
        painter: _WavePainter(isDark: isDark),
      ),
    );
  }

  Widget _buildDarkMonochrome(BuildContext context) {
    return Container(
      color: const Color(0xFF14141C),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Colors.white, Colors.transparent],
                    center: Alignment(-0.5, -0.5),
                    radius: 1.0,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Transform.rotate(
              angle: -pi / 2,
              child: Text(
                'THE\nARCHIVE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size * 0.12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                  height: 0.9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYellowAccent(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      color: isDark ? const Color(0xFF1F1F2B) : const Color(0xFF2C2C2C),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ScratchPainter(),
            ),
          ),
          Center(
            child: Transform.rotate(
              angle: -0.15,
              child: Text(
                'ART\nCREATES',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFF00E5FF) : const Color(0xFFE5F121),
                  height: 0.9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalistCircle(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Container(
      color: isDark ? const Color(0xFF252533) : const Color(0xFFEAEAEA),
      child: Stack(
        children: [
          Positioned(
            right: -size * 0.2,
            bottom: -size * 0.2,
            child: Container(
              width: size * 0.7,
              height: size * 0.7,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF6C5CE7).withOpacity(0.5) : const Color(0xFFA0A0A0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: size * 0.1,
            bottom: size * 0.1,
            child: Transform.rotate(
              angle: -pi / 2,
              child: Text(
                'MINDSET',
                style: TextStyle(
                  fontSize: size * 0.08,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final bool isDark;
  _WavePainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.5))
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(
        size.width * 0.5, size.height * 0.1, size.width, size.height * 0.4);
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScratchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final random = Random(42);
    for (int i = 0; i < 20; i++) {
      canvas.drawLine(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
