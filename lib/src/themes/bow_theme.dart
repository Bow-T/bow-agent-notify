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
