import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class VinylPlayerWidget extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final double progress; // 0.0 to 1.0
  final ValueChanged<double>? onSeek; // Callback when user drags

  const VinylPlayerWidget({
    super.key,
    required this.isPlaying,
    this.size = 280,
    this.progress = 0.0,
    this.onSeek,
  });

  @override
  State<VinylPlayerWidget> createState() => _VinylPlayerWidgetState();
}

class _VinylPlayerWidgetState extends State<VinylPlayerWidget>
    with TickerProviderStateMixin {
  late AnimationController _vinylController;
  late AnimationController _tonearmController;
  late Animation<double> _tonearmAnimation;
  double? _dragProgress;

  @override
  void initState() {
    super.initState();

    // Continuous 6s revolution for vinyl disc
    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    // Tonearm drop/lift animation
    _tonearmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _tonearmAnimation = Tween<double>(
      begin: -0.4, // Resting position (lifted away)
      end: 0.1,   // Dropped on vinyl record
    ).animate(
      CurvedAnimation(parent: _tonearmController, curve: Curves.easeInOut),
    );

    if (widget.isPlaying) {
      _vinylController.repeat();
      _tonearmController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant VinylPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _vinylController.repeat();
        _tonearmController.forward();
      } else {
        _vinylController.stop(canceled: false); // Hold angle in place
        _tonearmController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _vinylController.dispose();
    _tonearmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: widget.size + 40,
      height: widget.size + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular Progress Ring behind the vinyl
          CustomPaint(
            size: Size(widget.size + 28, widget.size + 28),
            painter: _CircularProgressPainter(
              progress: _dragProgress ?? widget.progress,
              trackColor: AppColors.dividerInactive.withOpacity(0.25),
              progressColor: AppColors.secondaryText,
              strokeWidth: 3.5,
            ),
          ),

          // Vinyl Record Disc
          AnimatedBuilder(
            animation: _vinylController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _vinylController.value * 2 * pi,
                child: child,
              );
            },
            child: RepaintBoundary(
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF151517),
                  boxShadow: AppColors.vinylShadow,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric Vinyl Grooves
                    for (double d in [0.88, 0.74, 0.60, 0.46])
                      Container(
                        width: widget.size * d,
                        height: widget.size * d,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                            width: 1.5,
                          ),
                        ),
                      ),
                    // Central Vinyl Album Label
                    Container(
                      width: widget.size * 0.35,
                      height: widget.size * 0.35,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent,
                            Color(0xFFF0C2BA),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.background,
                            border: Border.all(color: Colors.black26, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tonearm Graphic positioned top right
          Positioned(
            top: 0,
            right: 20,
            child: AnimatedBuilder(
              animation: _tonearmAnimation,
              builder: (context, child) {
                return Transform(
                  transform: Matrix4.identity()
                    ..rotateZ(_tonearmAnimation.value),
                  alignment: Alignment.topRight,
                  child: child,
                );
              },
              child: SizedBox(
                width: 70,
                height: 140,
                child: CustomPaint(
                  painter: TonearmPainter(),
                ),
              ),
            ),
          ),

          // Draggable thumb dot on progress ring
          if (widget.onSeek != null)
            _CircularSeekThumb(
              ringDiameter: widget.size + 28,
              progress: _dragProgress ?? widget.progress,
            ),
        ],
      ),
    );
    
    if (widget.onSeek != null) {
      return GestureDetector(
        onPanStart: (details) => _handleSeekGesture(details.localPosition),
        onPanUpdate: (details) => _handleSeekGesture(details.localPosition),
        onPanEnd: (details) {
          if (_dragProgress != null) {
            widget.onSeek!(_dragProgress!);
            setState(() => _dragProgress = null);
          }
        },
        onTapDown: (details) => _handleSeekGesture(details.localPosition),
        onTapUp: (details) {
          if (_dragProgress != null) {
            widget.onSeek!(_dragProgress!);
            setState(() => _dragProgress = null);
          }
        },
        child: content,
      );
    }
    
    return content;
  }

  void _handleSeekGesture(Offset localPosition) {
    final center = Offset((widget.size + 40) / 2, (widget.size + 40) / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    
    var newAngle = atan2(dy, dx) + pi / 2;
    if (newAngle < 0) newAngle += 2 * pi;
    final newProgress = (newAngle / (2 * pi)).clamp(0.0, 1.0);
    
    setState(() {
      _dragProgress = newProgress;
    });
  }
}

// ---------- Circular Progress Ring Painter ----------

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    // Background track ring
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (starts from top, -pi/2)
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,       // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ---------- Draggable seek thumb on the ring ----------

class _CircularSeekThumb extends StatelessWidget {
  final double ringDiameter;
  final double progress;

  const _CircularSeekThumb({
    required this.ringDiameter,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final radius = ringDiameter / 2;
    // Angle from top (-pi/2)
    final angle = -pi / 2 + 2 * pi * progress.clamp(0.0, 1.0);
    final thumbX = radius + (radius - 4) * cos(angle);
    final thumbY = radius + (radius - 4) * sin(angle);

    return Positioned(
      left: thumbX - 8,
      top: thumbY - 8,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textPrimary(context),
          border: Border.all(color: AppColors.surface(context), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Tonearm painter ----------

class TonearmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = const Color(0xFF333338)
      ..style = PaintingStyle.fill;

    final armPaint = Paint()
      ..color = const Color(0xFF8E8E93)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final headShellPaint = Paint()
      ..color = const Color(0xFF1C1C1E)
      ..style = PaintingStyle.fill;

    // Base pivot
    canvas.drawCircle(Offset(size.width - 15, 15), 14, basePaint);
    canvas.drawCircle(Offset(size.width - 15, 15), 6, Paint()..color = const Color(0xFFC9C7D1));

    // Curved Tonearm rod
    final path = Path();
    path.moveTo(size.width - 15, 15);
    path.lineTo(size.width - 25, 70);
    path.lineTo(25, size.height - 25);
    canvas.drawPath(path, armPaint);

    // Head Shell / Cartridge
    canvas.save();
    canvas.translate(25, size.height - 25);
    canvas.rotate(0.4);
    final headRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-6, -2, 14, 22),
      const Radius.circular(3),
    );
    canvas.drawRRect(headRect, headShellPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
