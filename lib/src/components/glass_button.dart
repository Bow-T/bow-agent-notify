import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

enum GlassButtonKind { plain, primary, danger }

/// Nút viên thuốc của theme kính: thường = kính sáng, chính = lam chuyển sắc, nguy hiểm = đỏ.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = GlassButtonKind.plain,
    this.large = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GlassButtonKind kind;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final solid = switch (kind) {
      GlassButtonKind.plain => null,
      GlassButtonKind.primary => c.accent,
      GlassButtonKind.danger => c.danger,
    };
    final foreground = solid == null ? c.ink : Colors.white;
    final decoration = solid == null
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.hairline),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: c.button,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 10,
                spreadRadius: -6,
                offset: Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Color.lerp(solid, Colors.white, 0.45)!),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(solid, Colors.white, 0.22)!,
                solid,
                Color.lerp(solid, Colors.black, 0.14)!,
              ],
              stops: const [0, 0.46, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: solid.withValues(alpha: 0.55),
                blurRadius: 26,
                spreadRadius: -12,
                offset: const Offset(0, 12),
              ),
            ],
          );
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: large ? 22 : 16,
                vertical: large ? 15 : 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: large ? 20 : 17, color: foreground),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        fontSize: large ? 16 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
