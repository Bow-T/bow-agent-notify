import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Xác thực bằng vân tay / khuôn mặt / mật mã máy.
class BiometricService {
  const BiometricService();

  /// `true` / `false` = người dùng xác thực được / không. `null` = máy KHÔNG xác thực được (chưa đặt khoá màn hình,
  /// chưa đăng ký sinh trắc) — caller hỏi lại bằng một hộp xác nhận, vẫn hơn một cú chạm nhầm.
  Future<bool?> confirm(String reason) async {
    final auth = LocalAuthentication();
    try {
      if (await auth.isDeviceSupported()) {
        return await auth.authenticate(localizedReason: reason);
      }
    } catch (_) {
      // rơi xuống `null`
    }
    return null;
  }
}

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => const BiometricService(),
);
