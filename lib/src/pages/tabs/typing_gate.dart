import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/biometric_service.dart';
import '../../services/prefs_store.dart';
import '../../utils/l10n.dart';

/// Một lần mở khoá gõ có hiệu lực bao nhiêu PHÚT — chọn ở Cài đặt → Bảo mật, lưu lại giữa các lần mở app.
class UnlockMinutes extends Notifier<int> {
  /// Các mức cho chọn. Không có "không bao giờ khoá": app ra nền là khoá lại, bất kể mức nào.
  static const choices = [1, 5, 15];
  static const _key = 'unlock_minutes';
  static const _default = 5;

  @override
  int build() => _default;

  /// Nạp mức đã lưu (gọi lúc app khởi động). Giá trị lạ — bản app khác ghi — thì giữ mặc định.
  Future<void> load() async {
    try {
      final saved = await ref.read(prefsStoreProvider).readInt(_key);
      if (saved != null && choices.contains(saved)) state = saved;
    } catch (_) {
      // Không đọc được: giữ mặc định.
    }
  }

  void set(int minutes) {
    if (!choices.contains(minutes) || minutes == state) return;
    state = minutes;
    unawaited(
      ref
          .read(prefsStoreProvider)
          .writeInt(_key, minutes)
          .catchError((Object _) {}),
    );
  }
}

final unlockMinutesProvider = NotifierProvider<UnlockMinutes, int>(
  UnlockMinutes.new,
);

/// "Mở khoá gõ": gõ lệnh cho agent từ điện thoại phải qua vân tay / khuôn mặt / mật mã máy — MỘT lần cho một phiên
/// vài phút ([unlockMinutesProvider], mặc định 5), không phải mỗi tin (trò chuyện qua lại mà tin nào cũng quét thì
/// không ai dùng). App ra nền là khoá lại.
///
/// Trạng thái = lúc hết hạn mở khoá (`null` = đang khoá). Chốt này nằm ở APP: nó chặn người cầm máy đang mở khoá,
/// không chặn kẻ đã có khoá ghép máy — chốt thật là công tắc quyền trên web + cổng duyệt của lượt chạy.
class TypingGate extends Notifier<DateTime?> {
  /// Thời hạn của lần mở khoá sắp tới. Đổi mức trong Cài đặt không kéo dài phiên đang mở.
  Duration get _window => Duration(minutes: ref.read(unlockMinutesProvider));

  @override
  DateTime? build() => null;

  bool get unlocked {
    final until = state;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Bảo đảm đang mở khoá. Máy không xác thực được (chưa đặt khoá màn hình) thì hỏi bằng [askFallback] (hộp xác nhận).
  Future<bool> ensure({required Future<bool> Function() askFallback}) async {
    if (unlocked) return true;
    final ok =
        await ref
            .read(biometricServiceProvider)
            .confirm(
              t(
                'Mở khoá để gõ lệnh cho agent',
                'Unlock to send prompts to the agent',
              ),
            ) ??
        await askFallback();
    if (!ok || !ref.mounted) return false;
    state = DateTime.now().add(_window);
    return true;
  }

  /// Vừa xác thực ở chỗ khác (giao việc mới luôn hỏi vân tay) — mở luôn phiên gõ để câu tiếp theo khỏi hỏi lại.
  void unlockNow() => state = DateTime.now().add(_window);

  /// App ra nền / người dùng tự khoá.
  void lock() => state = null;
}

final typingGateProvider = NotifierProvider<TypingGate, DateTime?>(
  TypingGate.new,
);
