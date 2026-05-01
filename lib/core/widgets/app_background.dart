import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (!enabled) {
      return ColoredBox(
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
        child: child,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const <Color>[
                  Color(0xFF07101F),
                  Color(0xFF0A1424),
                  Color(0xFF101B2D),
                ]
              : const <Color>[
                  Color(0xFFF5F8FD),
                  Color(0xFFEAF1FB),
                  Color(0xFFF8FAFC),
                ],
        ),
      ),
      child: CustomPaint(
        painter: _StarFieldPainter(isDark: isDark),
        child: child,
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: isDark
                ? <Color>[
                    const Color(0xFF355CA8).withValues(alpha: 0.35),
                    const Color(0xFF17233E).withValues(alpha: 0.06),
                    Colors.transparent,
                  ]
                : <Color>[
                    const Color(0xFF91B8F8).withValues(alpha: 0.25),
                    const Color(0xFFDCEAFF).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.48, size.height * 0.26),
              radius: size.width * 0.58,
            ),
          );

    canvas.drawCircle(
      Offset(size.width * 0.48, size.height * 0.26),
      size.width * 0.58,
      glowPaint,
    );

    final Path skyPatch = Path()
      ..moveTo(size.width * 0.10, size.height * 0.02)
      ..cubicTo(
        size.width * 0.32,
        -size.height * 0.03,
        size.width * 0.62,
        size.height * 0.02,
        size.width * 0.74,
        size.height * 0.15,
      )
      ..cubicTo(
        size.width * 0.90,
        size.height * 0.32,
        size.width * 0.86,
        size.height * 0.58,
        size.width * 0.66,
        size.height * 0.68,
      )
      ..cubicTo(
        size.width * 0.44,
        size.height * 0.78,
        size.width * 0.22,
        size.height * 0.63,
        size.width * 0.13,
        size.height * 0.43,
      )
      ..cubicTo(
        -size.width * 0.02,
        size.height * 0.22,
        -size.width * 0.03,
        size.height * 0.08,
        size.width * 0.10,
        size.height * 0.02,
      )
      ..close();

    final Paint patchPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? <Color>[
                const Color(0xFF223B82).withValues(alpha: 0.30),
                const Color(0xFF6679AD).withValues(alpha: 0.20),
                const Color(0xFF1B2C55).withValues(alpha: 0.08),
              ]
            : <Color>[
                const Color(0xFF9ABCF8).withValues(alpha: 0.18),
                const Color(0xFFD7E4FF).withValues(alpha: 0.20),
                const Color(0xFFBBD1F6).withValues(alpha: 0.10),
              ],
      ).createShader(Offset.zero & size);

    canvas.save();
    canvas.translate(size.width * 0.14, size.height * 0.02);
    canvas.rotate(-0.16);
    canvas.drawPath(skyPatch, patchPaint);
    _paintStars(canvas, size);
    canvas.restore();
  }

  void _paintStars(Canvas canvas, Size size) {
    final math.Random random = math.Random(24);
    final Paint starPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF3F6EC8)).withValues(
        alpha: isDark ? 0.72 : 0.20,
      );

    for (int index = 0; index < 110; index++) {
      final double x = random.nextDouble() * size.width * 0.80;
      final double y = random.nextDouble() * size.height * 0.58;
      final double radius = 0.45 + random.nextDouble() * 1.05;
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }

    final Paint brightStarPaint = Paint()
      ..color = (isDark ? const Color(0xFFB9C8FF) : const Color(0xFF6B8FE5))
          .withValues(alpha: isDark ? 0.90 : 0.28);

    for (final Offset star in <Offset>[
      Offset(size.width * 0.22, size.height * 0.16),
      Offset(size.width * 0.58, size.height * 0.23),
      Offset(size.width * 0.70, size.height * 0.36),
    ]) {
      canvas.drawCircle(star, 1.7, brightStarPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) {
    return isDark != oldDelegate.isDark;
  }
}
