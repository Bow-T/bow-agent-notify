import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appearance.dart';
import '../themes/bow_theme.dart';

const _styleKey = 'ui_style';
const _modeKey = 'ui_mode';
const _languageKey = 'ui_language';

/// Lựa chọn giao diện — lưu trong vùng dữ liệu riêng của app, theo TÊN của giá trị (tên lạ / chưa lưu = mặc định, nên
/// bản app cũ đọc dữ liệu của bản mới cũng không vỡ).
class AppearanceStore {
  const AppearanceStore();

  /// `fresh`: đọc lại từ đĩa — phần chạy nền là một isolate riêng, bộ nhớ đệm của nó không biết app vừa đổi gì.
  Future<Appearance> load({bool fresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (fresh) await prefs.reload();
    return (
      style:
          BowStyle.values.asNameMap()[prefs.getString(_styleKey)] ??
          defaultAppearance.style,
      mode:
          GlassMode.values.asNameMap()[prefs.getString(_modeKey)] ??
          defaultAppearance.mode,
      language:
          AppLanguage.values.asNameMap()[prefs.getString(_languageKey)] ??
          defaultAppearance.language,
    );
  }

  Future<void> save(Appearance appearance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, appearance.style.name);
    await prefs.setString(_modeKey, appearance.mode.name);
    await prefs.setString(_languageKey, appearance.language.name);
  }
}

final appearanceStoreProvider = Provider<AppearanceStore>(
  (ref) => const AppearanceStore(),
);
