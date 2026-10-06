import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/appearance.dart';
import '../../services/appearance_store.dart';
import '../../themes/bow_theme.dart';

/// ViewModel của lựa chọn giao diện. `MaterialApp` đọc nó để chọn theme, Cài đặt → Giao diện đổi nó. Đổi là áp ngay và
/// lưu lại; ghi đĩa hỏng thì lựa chọn vẫn có hiệu lực cho tới khi đóng app.
class AppearanceVm extends Notifier<Appearance> {
  @override
  Appearance build() => defaultAppearance;

  /// Nạp lựa chọn đã lưu — gọi TRƯỚC `runApp` để khung hình đầu tiên đã đúng theme (không nháy từ kính sang brutal).
  Future<void> load() async {
    try {
      state = await ref.read(appearanceStoreProvider).load();
    } catch (_) {
      // Không đọc được: giữ mặc định.
    }
  }

  void setStyle(BowStyle style) => _set((style: style, mode: state.mode));

  void setMode(GlassMode mode) => _set((style: state.style, mode: mode));

  void _set(Appearance next) {
    if (next == state) return;
    state = next;
    unawaited(
      ref.read(appearanceStoreProvider).save(next).catchError((Object _) {}),
    );
  }
}

final appearanceVmProvider = NotifierProvider<AppearanceVm, Appearance>(
  AppearanceVm.new,
);
