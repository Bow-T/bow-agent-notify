import '../themes/bow_theme.dart';

/// Chế độ màu của theme kính: theo cài đặt của máy, hoặc ép sáng / tối. Brutal chỉ có một bản sáng nên không dùng.
enum GlassMode { system, light, dark }

/// Ngôn ngữ của app: theo máy, hoặc ép một trong hai thứ tiếng app có.
enum AppLanguage {
  system(null),
  vi('vi'),
  en('en');

  const AppLanguage(this.code);

  /// Mã ngôn ngữ ép cho `t()`; `null` = theo máy.
  final String? code;
}

/// Lựa chọn giao diện của người dùng: phong cách (kính / brutal), chế độ màu của kính, ngôn ngữ.
typedef Appearance = ({BowStyle style, GlassMode mode, AppLanguage language});

/// Lần đầu cài: kính, sáng / tối và ngôn ngữ theo máy — đúng giao diện app vẫn có trước khi có các lựa chọn này.
const Appearance defaultAppearance = (
  style: BowStyle.glass,
  mode: GlassMode.system,
  language: AppLanguage.system,
);
