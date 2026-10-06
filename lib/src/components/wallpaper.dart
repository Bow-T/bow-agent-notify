import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

/// Hình nền của app. Theme kính: "Cực quang" — mẫu mặc định của web (`[data-wallpaper='aurora']`), bốn mảng màu ở bốn
/// góc; bản sáng giữ nguyên bốn màu nhưng nhạt đi. Theme brutal: nền kem phẳng có lưới chấm mực (như `.app` của web).
class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    if (c.isBrutal) {
      return ColoredBox(
        color: c.bg,
        child: CustomPaint(
          painter: _DotGrid(c.ink.withValues(alpha: 0.42)),
          child: child,
        ),
      );
    }
    Widget blob(Alignment center, Color color, double opacity, double radius) =>
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: center,
                radius: radius,
                colors: [
                  color.withValues(alpha: opacity * c.blobs),
                  color.withValues(alpha: 0),
                ],
                stops: const [0, 0.7],
              ),
            ),
          ),
        );
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: c.bg)),
        blob(const Alignment(-0.9, -1), const Color(0xFF6260E8), 0.85, 1.25),
        blob(const Alignment(0.95, -0.96), c.accent, 0.72, 1.1),
        blob(const Alignment(0.8, 1), const Color(0xFFBF5AF2), 0.66, 1.25),
        blob(const Alignment(-0.85, 1), const Color(0xFF30BED2), 0.56, 1.15),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Lưới chấm của brutal: chấm 1,4 px cách nhau 22 px (web: `radial-gradient(var(--grid) 1.4px, …)` trên ô 22 px).
class _DotGrid extends CustomPainter {
  const _DotGrid(this.color);

  final Color color;

  static const _step = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(PointMode.points, [
      for (var y = _step / 2; y < size.height; y += _step)
        for (var x = _step / 2; x < size.width; x += _step) Offset(x, y),
    ], paint);
  }

  @override
  bool shouldRepaint(_DotGrid old) => old.color != color;
}
