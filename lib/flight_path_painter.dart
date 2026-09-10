import 'dart:math';

import 'package:flutter/material.dart';

import 'game/models.dart';
import 'theme.dart';

/// Draws the animated scene: rotating light rays, scrolling axis dots, the
/// red flight curve and the plane. Purely decorative — all game logic lives on
/// the server and is mirrored by GameClient.
class FlightScenePainter extends CustomPainter {
  FlightScenePainter({
    required this.phase,
    required this.flightSeconds,
    required this.crashedSeconds,
    required this.time,
  });

  final RoundPhase phase;
  final double flightSeconds;
  final double crashedSeconds;
  final double time;

  static const double _axisBase = 24;

  /// Global scale so the scene degrades gracefully in small viewports.
  double _scale(Size size) =>
      (min(size.width, size.height) / 300).clamp(0.5, 1.0);

  double _axis(Size size) => _axisBase * _scale(size);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final s = _scale(size);
    final axis = _axis(size);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF15161F), Color(0xFF0A0A10)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.9, 1),
          radius: 1.4,
          colors: [
            const Color(0xFF2A2C45).withValues(alpha: 0.9),
            const Color(0xFF2A2C45).withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    _drawRays(canvas, size);
    _drawGrid(canvas, size);
    _drawAxes(canvas, size);

    final origin = Offset(axis + 6 * s, h - axis - 6 * s);
    var planePos = origin;

    if (phase != RoundPhase.betting) {
      final p = 1 - exp(-flightSeconds / 7);
      final maxX = w - 46 * s;
      final maxY = h * 0.16 + 20 * s;
      final bob = sin(flightSeconds * 1.6) * 8 * s * p;
      final end = Offset(
        origin.dx + (maxX - origin.dx) * p,
        origin.dy - (origin.dy - maxY) * p + bob,
      );

      final curve = Path()
        ..moveTo(origin.dx, origin.dy)
        ..quadraticBezierTo(
          origin.dx + (end.dx - origin.dx) * 0.65,
          origin.dy,
          end.dx,
          end.dy,
        );
      final fill = Path.from(curve)
        ..lineTo(end.dx, origin.dy)
        ..close();

      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.red.withValues(alpha: 0.38),
              AppColors.red.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTRB(0, end.dy, w, origin.dy)),
      );
      canvas.drawPath(
        curve,
        Paint()
          ..color = AppColors.red.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9 * s
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * s),
      );
      canvas.drawPath(
        curve,
        Paint()
          ..color = AppColors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * s
          ..strokeCap = StrokeCap.round,
      );

      planePos = end;
      if (phase == RoundPhase.crashed) {
        final t = crashedSeconds;
        planePos = end.translate(t * t * w * 1.4 + t * 80, -t * h * 0.35);
      }
    }

    _drawPlane(canvas, planePos, spin: time, angle: -0.22, scale: s);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final axis = _axis(size);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const gap = 48.0;
    for (var x = axis + gap; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height - axis), paint);
    }
    for (var y = size.height - axis - gap; y > 0; y -= gap) {
      canvas.drawLine(Offset(axis, y), Offset(size.width, y), paint);
    }
  }

  void _drawRays(Canvas canvas, Size size) {
    final center = Offset(0, size.height);
    final radius = (size.width + size.height) * 2;
    const n = 12;
    const quadrant = pi / 2;
    const step = quadrant / n;
    final rot = (time * 0.12) % step;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomLeft,
        radius: 1.6,
        colors: [
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);

    for (var i = 0; i < n; i++) {
      final a0 = -quadrant + rot + i * step;
      final a1 = a0 + step / 2;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + cos(a0) * radius, center.dy + sin(a0) * radius)
        ..lineTo(center.dx + cos(a1) * radius, center.dy + sin(a1) * radius)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final axis = _axis(size);
    final s = _scale(size);
    final strip = Paint()..color = const Color(0xFF0B0B12);
    canvas.drawRect(Rect.fromLTWH(0, h - axis, w, axis), strip);
    canvas.drawRect(Rect.fromLTWH(0, 0, axis, h), strip);
    final line = Paint()..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawLine(Offset(axis, h - axis), Offset(w, h - axis), line);
    canvas.drawLine(Offset(axis, 0), Offset(axis, h - axis), line);

    final moving = phase != RoundPhase.betting;
    final scroll = moving ? flightSeconds : 0.0;
    final dotR = 2 * s;

    final bottomDot = Paint()..color = Colors.white.withValues(alpha: 0.6);
    const gapX = 56.0;
    var x = axis + gapX - (scroll * 40) % gapX;
    for (; x < w; x += gapX) {
      canvas.drawCircle(Offset(x, h - axis / 2), dotR, bottomDot);
    }

    final leftDot = Paint()..color = AppColors.blue.withValues(alpha: 0.8);
    const gapY = 48.0;
    var y = (scroll * 28) % gapY;
    for (; y < h - axis; y += gapY) {
      canvas.drawCircle(Offset(axis / 2, y), dotR, leftDot);
    }
  }

  void _drawPlane(
    Canvas canvas,
    Offset pos, {
    required double spin,
    required double angle,
    required double scale,
  }) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    canvas.scale(scale);

    canvas.drawCircle(
      Offset.zero,
      26,
      Paint()
        ..color = AppColors.red.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    final body = Paint()..color = AppColors.red;
    final dark = Paint()..color = const Color(0xFFB0022A);

    final lowerWing = Path()
      ..moveTo(-4, 1)
      ..lineTo(-16, 17)
      ..lineTo(-5, 17)
      ..lineTo(9, 3)
      ..close();
    canvas.drawPath(lowerWing, dark);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 46, height: 11),
        const Radius.circular(6),
      ),
      body,
    );

    final tail = Path()
      ..moveTo(-16, -3)
      ..lineTo(-25, -15)
      ..lineTo(-18, -15)
      ..lineTo(-9, -3)
      ..close();
    canvas.drawPath(tail, body);

    final upperWing = Path()
      ..moveTo(-1, -4)
      ..lineTo(-9, -19)
      ..lineTo(-1, -19)
      ..lineTo(11, -4)
      ..close();
    canvas.drawPath(upperWing, dark);

    canvas.drawCircle(
      const Offset(7, -4.5),
      3.5,
      Paint()..color = const Color(0xFF1B1C2E),
    );

    canvas.save();
    canvas.translate(24, 0);
    canvas.rotate(spin * 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 3, height: 28),
        const Radius.circular(1.5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    canvas.restore();
    canvas.drawCircle(const Offset(23, 0), 3, Paint()..color = Colors.white);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FlightScenePainter old) => true;
}
