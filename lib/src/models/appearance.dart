import '../themes/bow_theme.dart';

/// Chế độ màu của theme kính: theo cài đặt của máy, hoặc ép sáng / tối. Brutal chỉ có một bản sáng nên không dùng.
enum GlassMode { system, light, dark }

/// Lựa chọn giao diện của người dùng: phong cách (kính / brutal) + chế độ màu của kính.
typedef Appearance = ({BowStyle style, GlassMode mode});

/// Lần đầu cài: kính, sáng / tối theo máy — đúng giao diện app vẫn có trước khi có lựa chọn này.
const Appearance defaultAppearance = (
  style: BowStyle.glass,
  mode: GlassMode.system,
);
