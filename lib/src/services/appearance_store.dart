import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appearance.dart';
import '../themes/bow_theme.dart';

const _styleKey = 'ui_style';
const _modeKey = 'ui_mode';

/// Lựa chọn giao diện — lưu trong vùng dữ liệu riêng của app, theo TÊN của giá trị (tên lạ / chưa lưu = mặc định, nên
/// bản app cũ đọc dữ liệu của bản mới cũng không vỡ).
class AppearanceStore {
  const AppearanceStore();

  Future<Appearance> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      style:
          BowStyle.values.asNameMap()[prefs.getString(_styleKey)] ??
          defaultAppearance.style,
      mode:
          GlassMode.values.asNameMap()[prefs.getString(_modeKey)] ??
          defaultAppearance.mode,
    );
  }

  Future<void> save(Appearance appearance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, appearance.style.name);
    await prefs.setString(_modeKey, appearance.mode.name);
  }
}

final appearanceStoreProvider = Provider<AppearanceStore>(
  (ref) => const AppearanceStore(),
);
