import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/biometric_service.dart';
import '../../utils/l10n.dart';

/// "Mở khoá gõ": gõ lệnh cho agent từ điện thoại phải qua vân tay / khuôn mặt / mật mã máy — MỘT lần cho một phiên
/// 5 phút, không phải mỗi tin (trò chuyện qua lại mà tin nào cũng quét thì không ai dùng). App ra nền là khoá lại.
///
/// Trạng thái = lúc hết hạn mở khoá (`null` = đang khoá). Chốt này nằm ở APP: nó chặn người cầm máy đang mở khoá,
/// không chặn kẻ đã có khoá ghép máy — chốt thật là công tắc quyền trên web + cổng duyệt của lượt chạy.
class TypingGate extends Notifier<DateTime?> {
  static const window = Duration(minutes: 5);

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
    state = DateTime.now().add(window);
    return true;
  }

  /// App ra nền / người dùng tự khoá.
  void lock() => state = null;
}

final typingGateProvider = NotifierProvider<TypingGate, DateTime?>(
  TypingGate.new,
);
