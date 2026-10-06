import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

/// `allow` / `deny` là cặp nút của thẻ duyệt: ở kính chúng trông như nút chính / nút thường; ở brutal là cặp khối
/// oải hương / san hô (đúng cặp "ALLOW / DENY" của web).
enum GlassButtonKind { plain, primary, danger, allow, deny }

/// Nút của app. Theme kính: viên thuốc — thường = kính sáng, chính = lam chuyển sắc, nguy hiểm = đỏ. Theme brutal:
/// khối màu phẳng viền mực + bóng cứng, chữ IN HOA đều nét màu mực.
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
    return c.isBrutal ? _brutal(c) : _glass(c);
  }

  Widget _content(Color foreground, TextStyle style, {bool upper = false}) =>
      Padding(
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
                upper ? label.toUpperCase() : label,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      );

  Widget _brutal(Bow c) {
    final fill = switch (kind) {
      GlassButtonKind.plain => c.well,
      GlassButtonKind.primary => c.accent,
      GlassButtonKind.danger || GlassButtonKind.deny => c.danger,
      GlassButtonKind.allow => c.teal,
    };
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: c.ink, width: c.line),
          boxShadow: c.hardShadow(large ? 3 : 2),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            child: _content(
              c.ink,
              TextStyle(
                color: c.ink,
                fontFamily: Bow.brutalMono,
                fontWeight: FontWeight.w700,
                fontSize: large ? 14 : 12.5,
                letterSpacing: 0.4,
              ),
              upper: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _glass(Bow c) {
    final solid = switch (kind) {
      GlassButtonKind.plain || GlassButtonKind.deny => null,
      GlassButtonKind.primary || GlassButtonKind.allow => c.accent,
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
            child: _content(
              foreground,
              TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
                fontSize: large ? 16 : 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
