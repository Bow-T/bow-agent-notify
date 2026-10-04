import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

/// Hình nền "Cực quang" — mẫu mặc định của web (`[data-wallpaper='aurora']`): bốn mảng màu ở bốn góc.
/// Bản sáng giữ nguyên bốn màu nhưng nhạt đi trên nền sáng.
class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
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
