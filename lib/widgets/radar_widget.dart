import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated radar compass widget. Shows sound direction as a glowing needle.
class RadarWidget extends StatefulWidget {
  final double? azimuth; // 0-360 degrees, null = no signal
  final double confidence;
  final bool isActive;

  const RadarWidget({
    super.key,
    required this.azimuth,
    required this.confidence,
    required this.isActive,
  });

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  double _displayAzimuth = 0;
  double _targetAzimuth = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);
    _pulseAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.linear));
  }

  @override
  void didUpdateWidget(RadarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.azimuth != null) {
      _targetAzimuth = widget.azimuth!;
    }
    if (widget.isActive) {
      if (!_pulseController.isAnimating) _pulseController.repeat();
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lerp azimuth for smooth needle movement
    final diff = ((_targetAzimuth - _displayAzimuth + 540) % 360) - 180;
    _displayAzimuth = (_displayAzimuth + diff * 0.15) % 360;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return SizedBox(
          width: 260,
          height: 260,
          child: CustomPaint(
            painter: _RadarPainter(
              azimuth: _displayAzimuth,
              confidence: widget.confidence,
              pulseValue: _pulseAnim.value,
              isActive: widget.isActive,
              hasSignal: widget.azimuth != null,
            ),
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double azimuth;
  final double confidence;
  final double pulseValue;
  final bool isActive;
  final bool hasSignal;

  _RadarPainter({
    required this.azimuth,
    required this.confidence,
    required this.pulseValue,
    required this.isActive,
    required this.hasSignal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background glow
    _drawBackground(canvas, center, radius);

    // Concentric rings
    _drawRings(canvas, center, radius);

    // Cardinal labels
    _drawCardinals(canvas, center, radius, size);

    // Rotating sweep line
    if (isActive) {
      _drawSweep(canvas, center, radius);
    }

    // Direction needle + confidence sector
    if (hasSignal) {
      _drawNeedle(canvas, center, radius);
    }

    // Center dot
    _drawCenter(canvas, center);
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.cyan.withValues(alpha: 0.04),
          AppColors.background.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bgPaint);
  }

  void _drawRings(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      final r = radius * (i / 4);
      final alpha = 0.08 + (i / 4) * 0.12;
      ringPaint.color = AppColors.cyan.withValues(alpha: alpha.toDouble());
      canvas.drawCircle(center, r, ringPaint);
    }

    // Cross lines
    final linePaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      center.translate(-radius, 0),
      center.translate(radius, 0),
      linePaint,
    );
    canvas.drawLine(
      center.translate(0, -radius),
      center.translate(0, radius),
      linePaint,
    );
  }

  void _drawCardinals(Canvas canvas, Offset center, double radius, Size size) {
    final style = const TextStyle(
      color: AppColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );
    final labels = ['N', 'E', 'S', 'W'];
    final offsets = [
      center.translate(0, -radius + 14),
      center.translate(radius - 14, 0),
      center.translate(0, radius - 14),
      center.translate(-radius + 14, 0),
    ];

    for (int i = 0; i < 4; i++) {
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, offsets[i].translate(-tp.width / 2, -tp.height / 2));
    }
  }

  void _drawSweep(Canvas canvas, Offset center, double radius) {
    final sweepAngle = pulseValue * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + math.pi / 2,
        colors: [
          AppColors.cyan.withValues(alpha: 0.0),
          AppColors.cyan.withValues(alpha: 0.18),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.92),
      sweepAngle,
      math.pi / 2,
      true,
      sweepPaint,
    );

    // Sweep tip line
    final tipPaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      center,
      center.translate(
        math.cos(sweepAngle) * radius * 0.9,
        math.sin(sweepAngle) * radius * 0.9,
      ),
      tipPaint,
    );
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    final angleRad = (azimuth - 90) * math.pi / 180;
    final needleLen = radius * 0.72;
    final tip = Offset(
      center.dx + math.cos(angleRad) * needleLen,
      center.dy + math.sin(angleRad) * needleLen,
    );

    // Confidence sector
    final sectorAngle = (math.pi / 3) * confidence;
    final sectorPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.cyan.withValues(alpha: 0.25 * confidence),
          AppColors.cyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: needleLen))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: needleLen),
      angleRad - sectorAngle / 2,
      sectorAngle,
      true,
      sectorPaint,
    );

    // Needle glow
    final glowPaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.2)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, glowPaint);

    // Needle
    final needlePaint = Paint()
      ..color = AppColors.cyan
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, needlePaint);

    // Tip dot
    final dotPaint = Paint()..color = AppColors.cyan;
    canvas.drawCircle(tip, 5, dotPaint);
    final dotGlowPaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(tip, 8, dotGlowPaint);
  }

  void _drawCenter(Canvas canvas, Offset center) {
    final glowPaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 8, glowPaint);
    canvas.drawCircle(center, 5, Paint()..color = AppColors.cyan);
    canvas.drawCircle(center, 3, Paint()..color = AppColors.background);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => true;
}
