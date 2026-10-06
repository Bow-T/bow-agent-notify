import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/appearance.dart';
import '../../services/appearance_store.dart';
import '../../themes/bow_theme.dart';
import '../../utils/l10n.dart';

/// ViewModel của lựa chọn giao diện. `MaterialApp` đọc nó để chọn theme, Cài đặt → Giao diện đổi nó. Đổi là áp ngay và
/// lưu lại; ghi đĩa hỏng thì lựa chọn vẫn có hiệu lực cho tới khi đóng app. Nó cũng là nơi DUY NHẤT đặt ngôn ngữ ép
/// cho `t()` (`forcedLanguage`).
class AppearanceVm extends Notifier<Appearance> {
  @override
  Appearance build() => defaultAppearance;

  /// Nạp lựa chọn đã lưu — gọi TRƯỚC `runApp` để khung hình đầu tiên đã đúng theme và đúng ngôn ngữ (không nháy).
  Future<void> load() async {
    try {
      _apply(await ref.read(appearanceStoreProvider).load());
    } catch (_) {
      // Không đọc được: giữ mặc định.
    }
  }

  void setStyle(BowStyle style) =>
      _set((style: style, mode: state.mode, language: state.language));

  void setMode(GlassMode mode) =>
      _set((style: state.style, mode: mode, language: state.language));

  void setLanguage(AppLanguage language) =>
      _set((style: state.style, mode: state.mode, language: language));

  void _apply(Appearance next) {
    // Trước khi đổi state: widget dựng lại theo state mới phải đọc được ngôn ngữ mới.
    forcedLanguage = next.language.code;
    state = next;
  }

  void _set(Appearance next) {
    if (next == state) return;
    _apply(next);
    unawaited(
      ref.read(appearanceStoreProvider).save(next).catchError((Object _) {}),
    );
  }
}

final appearanceVmProvider = NotifierProvider<AppearanceVm, Appearance>(
  AppearanceVm.new,
);
