import 'dart:ui';

import 'package:flutter/material.dart';

/// Màu + chất liệu "Liquid Glass" của web bow (repo bow-agent, `web/styles.css`: `[data-theme='glass']` và khối
/// `data-appearance='light'`). Hai bên không chung mã nguồn — đổi màu ở web thì đổi lại ở đây.
@immutable
class Bow {
  const Bow._({
    required this.isDark,
    required this.bg,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.danger,
    required this.ok,
    required this.teal,
    required this.paneTint,
    required this.pane,
    required this.button,
    required this.rim,
    required this.hairline,
    required this.shadow,
    required this.well,
    required this.blobs,
  });

  final bool isDark;
  final Color bg; // --bg (lớp dưới cùng của hình nền)
  final Color ink;
  final Color muted;
  final Color accent; // --brass
  final Color danger;
  final Color ok;
  final Color teal;
  final Color paneTint; // lớp nhuộm dưới của --glass-pane
  final List<Color> pane; // lớp ánh sáng của --glass-pane, trên → dưới
  final List<Color> button; // --glass-fill-hi
  final Color rim; // --glass-rim
  final Color hairline;
  final Color shadow; // --glass-drop
  final Color well; // --glass-well: ô nhập lõm xuống
  final double blobs; // độ đậm các mảng màu của hình nền

  static const light = Bow._(
    isDark: false,
    bg: Color(0xFFE6ECF6),
    ink: Color(0xFF1D1D1F),
    muted: Color(0xFF6E6E73),
    accent: Color(0xFF007AFF),
    danger: Color(0xFFFF3B30),
    ok: Color(0xFF1F9D47),
    teal: Color(0xFF0891C7),
    paneTint: Color(0x0FFFFFFF),
    pane: [Color(0xA8FFFFFF), Color(0x70FFFFFF)],
    button: [Color(0xFAFFFFFF), Color(0xCCFFFFFF)],
    rim: Color(0xCCFFFFFF),
    hairline: Color(0x1A000000),
    shadow: Color(0x4D14285A),
    well: Color(0x0D000000),
    blobs: 0.42,
  );

  static const dark = Bow._(
    isDark: true,
    bg: Color(0xFF0A0C1E),
    ink: Color(0xFFF6F8FF),
    muted: Color(0xFFA9B1CA),
    accent: Color(0xFF0A84FF),
    danger: Color(0xFFFF453A),
    ok: Color(0xFF30D158),
    teal: Color(0xFF64D2FF),
    paneTint: Color(0x4D101220),
    pane: [Color(0x24FFFFFF), Color(0x0AFFFFFF)],
    button: [Color(0x33FFFFFF), Color(0x12FFFFFF)],
    rim: Color(0x29FFFFFF),
    hairline: Color(0x24FFFFFF),
    shadow: Color(0x99000000),
    well: Color(0x42000000),
    blobs: 1,
  );

  static Bow of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Theme Material lót bên dưới — để hộp thoại, ô nhập, thanh báo cũng theo đúng bảng màu.
ThemeData bowTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? Bow.dark : Bow.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
      ).copyWith(
        primary: c.accent,
        error: c.danger,
        surface: c.bg,
        onSurface: c.ink,
      );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    splashFactory: InkSparkle.splashFactory,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.isDark
          ? const Color(0xF21C1F34)
          : const Color(0xF21D1D1F),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        height: 1.4,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.well,
      hintStyle: TextStyle(color: c.muted),
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
    ),
  );
}

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

/// Tấm kính: làm mờ thứ phía sau → nhuộm → ánh sáng đổ từ trên xuống, viền bắt sáng, bóng đổ mềm.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Nhuộm thêm một màu (thẻ cảnh báo).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 36,
            spreadRadius: -18,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(color: tint ?? c.paneTint),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                border: Border.all(color: c.rim),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: c.pane,
                ),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

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

/// Dấu hồng tâm của bow (web: `.brand-mark` trong App.tsx) — vòng tròn, chữ thập, chấm giữa.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _BrandMarkPainter(color));
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 32; // cùng hệ toạ độ 32×32 với SVG của web
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, 10.5 * unit, stroke..strokeWidth = 1.6 * unit);
    stroke.strokeWidth = unit;
    canvas.drawLine(
      Offset(center.dx, 3.5 * unit),
      Offset(center.dx, 28.5 * unit),
      stroke,
    );
    canvas.drawLine(
      Offset(3.5 * unit, center.dy),
      Offset(28.5 * unit, center.dy),
      stroke,
    );
    canvas.drawCircle(center, 2.6 * unit, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter old) => old.color != color;
}

/// Dấu hồng tâm trong đĩa kính, có vòng sóng toả ra khi đang nghe — "agent còn sống và đang nối với máy này".
class ListeningMark extends StatefulWidget {
  const ListeningMark({super.key, required this.active});

  final bool active;

  @override
  State<ListeningMark> createState() => _ListeningMarkState();
}

class _ListeningMarkState extends State<ListeningMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat();
  }

  @override
  void didUpdateWidget(ListeningMark old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    if (widget.active) {
      _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final color = widget.active ? c.accent : c.muted;
    Widget ring(double phase) => AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = (_pulse.value + phase) % 1;
        return Container(
          width: 56 + 40 * t,
          height: 56 + 40 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: widget.active ? 0.5 * (1 - t) : 0),
              width: 1.5,
            ),
          ),
        );
      },
    );
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(0),
          ring(0.5),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: c.button,
              ),
              border: Border.all(color: c.rim),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 22,
                  spreadRadius: -6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: BrandMark(size: 34, color: color),
          ),
        ],
      ),
    );
  }
}
