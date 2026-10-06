import 'package:flutter/material.dart';

/// Hai phong cách của web bow (`<html data-theme>` ở repo bow-agent): **kính** (Liquid Glass — có bản sáng và bản tối)
/// và **brutal** (Neo Brutalism — nền kem, viền mực dày, bóng cứng, góc vuông; chỉ có một bản sáng).
enum BowStyle { glass, brutal }

/// Màu + chất liệu của giao diện, chép từ `web/styles.css` của bow-agent (khối `[data-theme='glass']`,
/// `[data-appearance='light']` và `[data-theme='brutal']`). Hai bên không chung mã nguồn — đổi màu ở web thì đổi lại ở
/// đây. Widget lấy bộ đang áp bằng [Bow.of]; thứ khác nhau về HÌNH giữa hai phong cách (bo góc, bề dày viền, bóng) hỏi
/// qua [radius] / [line] / [hardShadow] thay vì tự rẽ nhánh.
@immutable
class Bow extends ThemeExtension<Bow> {
  const Bow._({
    required this.style,
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.danger,
    required this.onDanger,
    required this.dangerInk,
    required this.ok,
    required this.teal,
    required this.paneTint,
    required this.pane,
    required this.button,
    required this.rim,
    required this.hairline,
    required this.shadow,
    required this.well,
    required this.thick,
    required this.blobs,
  });

  final BowStyle style;
  final bool isDark;
  final Color bg; // --bg (lớp dưới cùng của hình nền)
  final Color
  surface; // --surface: nền thẻ ĐẶC của brutal (kính không dùng — thẻ của nó là tấm kính)
  final Color ink;
  final Color muted;
  final Color accent; // --brass: màu nhấn dạng KHỐI (nút chính, mục đang chọn)
  final Color onAccent; // --on-brass: chữ trên khối màu nhấn
  final Color
  accentInk; // màu nhấn dạng CHỮ / nét (link, vòng xoay) — vàng của brutal không đọc được trên nền kem
  final Color danger; // khối nguy hiểm (nút, nền cảnh báo)
  final Color onDanger;
  final Color dangerInk; // chữ cảnh báo
  final Color ok;
  final Color
  teal; // kính: lam ngọc; brutal: tím oải hương (--teal = landing --lav), khối "cho phép"
  final Color paneTint; // lớp nhuộm dưới của --glass-pane
  final List<Color> pane; // lớp ánh sáng của --glass-pane, trên → dưới
  final List<Color> button; // --glass-fill-hi
  final Color rim; // --glass-rim
  final Color hairline;
  final Color shadow; // --glass-drop
  final Color
  well; // --glass-well / --surface-2: ô lõm, nền nút thường của brutal
  final Color
  thick; // --glass-thick: lớp NỔI (hộp thoại, thanh điều hướng) phải đục hơn tấm thường
  final double blobs; // độ đậm các mảng màu của hình nền

  bool get isBrutal => style == BowStyle.brutal;

  static const light = Bow._(
    style: BowStyle.glass,
    isDark: false,
    bg: Color(0xFFE6ECF6),
    surface: Color(0xA8FFFFFF),
    ink: Color(0xFF1D1D1F),
    muted: Color(0xFF6E6E73),
    accent: Color(0xFF007AFF),
    onAccent: Colors.white,
    accentInk: Color(0xFF007AFF),
    danger: Color(0xFFFF3B30),
    onDanger: Colors.white,
    dangerInk: Color(0xFFFF3B30),
    ok: Color(0xFF1F9D47),
    teal: Color(0xFF0891C7),
    paneTint: Color(0x0FFFFFFF),
    pane: [Color(0xA8FFFFFF), Color(0x70FFFFFF)],
    button: [Color(0xFAFFFFFF), Color(0xCCFFFFFF)],
    rim: Color(0xCCFFFFFF),
    hairline: Color(0x1A000000),
    shadow: Color(0x4D14285A),
    well: Color(0x0D000000),
    thick: Color(0xCCF6F7FB),
    blobs: 0.42,
  );

  static const dark = Bow._(
    style: BowStyle.glass,
    isDark: true,
    bg: Color(0xFF0A0C1E),
    surface: Color(0x24FFFFFF),
    ink: Color(0xFFF6F8FF),
    muted: Color(0xFFA9B1CA),
    accent: Color(0xFF0A84FF),
    onAccent: Colors.white,
    accentInk: Color(0xFF0A84FF),
    danger: Color(0xFFFF453A),
    onDanger: Colors.white,
    dangerInk: Color(0xFFFF453A),
    ok: Color(0xFF30D158),
    teal: Color(0xFF64D2FF),
    paneTint: Color(0x4D101220),
    pane: [Color(0x24FFFFFF), Color(0x0AFFFFFF)],
    button: [Color(0x33FFFFFF), Color(0x12FFFFFF)],
    rim: Color(0x29FFFFFF),
    hairline: Color(0x24FFFFFF),
    shadow: Color(0x99000000),
    well: Color(0x42000000),
    thick: Color(0xB81B1E32),
    blobs: 1,
  );

  /// Neo Brutalism: kem · mực · vàng · san hô · oải hương. Chữ trên MỌI khối màu là mực đen.
  static const brutal = Bow._(
    style: BowStyle.brutal,
    isDark: false,
    bg: Color(0xFFFBF6E9),
    surface: Color(0xFFFFFDF5),
    ink: Color(0xFF0A0A0A),
    muted: Color(0xFF4A4A4A),
    accent: Color(0xFFFFCF24),
    onAccent: Color(0xFF0A0A0A),
    accentInk: Color(0xFF0A0A0A),
    danger: Color(0xFFFF5A5A),
    onDanger: Color(0xFF0A0A0A),
    dangerInk: Color(
      0xFFC81E1E,
    ), // --step-error: san hô trên nền kem quá nhạt để làm chữ
    ok: Color(0xFF157F3B),
    teal: Color(0xFFB8A4FF),
    paneTint: Color(0xFFFFFDF5),
    pane: [Color(0xFFFFFDF5), Color(0xFFFFFDF5)],
    button: [Color(0xFFFDF3D6), Color(0xFFFDF3D6)],
    rim: Color(0xFF0A0A0A),
    hairline: Color(0xFF0A0A0A),
    shadow: Color(0xFF0A0A0A),
    well: Color(0xFFFDF3D6),
    thick: Color(0xFFFFFDF5),
    blobs: 0,
  );

  /// Phông chữ của brutal (như web): Space Grotesk cho chữ thường, Space Mono cho nhãn / nút.
  static const brutalSans = 'Space Grotesk';
  static const brutalMono = 'Space Mono';

  /// Bộ token đang áp cho cây widget này (do [bowTheme] gắn vào theme).
  static Bow of(BuildContext context) => Theme.of(context).extension<Bow>()!;

  /// Bo góc: [glass] ở theme kính, VUÔNG ở brutal.
  BorderRadius radius(double glass) =>
      isBrutal ? BorderRadius.zero : BorderRadius.circular(glass);

  /// Bề dày viền: mảnh ở kính, DÀY ở brutal (`--bd-thin`).
  double get line => isBrutal ? 2 : 1;

  /// Bóng cứng của brutal: khối mực lệch [offset] px, không nhoè.
  List<BoxShadow> hardShadow(double offset) => [
    BoxShadow(color: ink, offset: Offset(offset, offset)),
  ];

  /// Kiểu chữ nhãn: brutal dùng chữ đều nét (mono), kính giữ phông đang có.
  TextStyle label(TextStyle base) =>
      isBrutal ? base.copyWith(fontFamily: brutalMono) : base;

  @override
  Bow copyWith() => this;

  /// Đổi theme là đổi HẲN (hình khối cũng khác) — không có trạng thái lưng chừng để pha màu.
  @override
  Bow lerp(Bow? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Theme Material lót bên dưới — để hộp thoại, ô nhập, thanh báo, công tắc cũng theo đúng bộ token [c].
ThemeData bowTheme(Bow c) {
  final brightness = c.isDark ? Brightness.dark : Brightness.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
      ).copyWith(
        primary: c.accentInk,
        error: c.dangerInk,
        surface: c.bg,
        onSurface: c.ink,
      );
  OutlineInputBorder inputBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: c.radius(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return ThemeData(
    colorScheme: scheme,
    extensions: [c],
    fontFamily: c.isBrutal ? Bow.brutalSans : null,
    scaffoldBackgroundColor: c.bg,
    splashFactory: InkSparkle.splashFactory,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.isBrutal
          ? c.ink
          : c.isDark
          ? const Color(0xF21C1F34)
          : const Color(0xF21D1D1F),
      contentTextStyle: TextStyle(
        color: c.isBrutal ? c.bg : Colors.white,
        fontSize: 14,
        height: 1.4,
        fontFamily: c.isBrutal ? Bow.brutalSans : null,
      ),
      shape: RoundedRectangleBorder(borderRadius: c.radius(18)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.isBrutal ? c.surface : c.well,
      hintStyle: TextStyle(color: c.muted),
      contentPadding: const EdgeInsets.all(12),
      border: inputBorder(c.hairline, c.line),
      enabledBorder: inputBorder(c.hairline, c.line),
      focusedBorder: inputBorder(c.accentInk, c.isBrutal ? 3 : 1.5),
    ),
    // Công tắc của brutal: rãnh vàng viền mực, núm mực (mặc định của Material pha màu theo seed, lạc khỏi bảng màu).
    switchTheme: c.isBrutal
        ? SwitchThemeData(
            thumbColor: WidgetStatePropertyAll(c.ink),
            trackColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.selected) ? c.accent : c.surface,
            ),
            trackOutlineColor: WidgetStatePropertyAll(c.ink),
            trackOutlineWidth: const WidgetStatePropertyAll(2),
          )
        : null,
  );
}
