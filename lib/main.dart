import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'src/pages/settings/appearance_vm.dart';
import 'src/pages/tabs/typing_gate.dart';
import 'src/services/background.dart';
import 'src/services/home_widget_service.dart';
import 'src/services/notification_service.dart';

/// Bow Notify — app đồng hành của bow-agent: nhận thông báo đẩy (FCM) và, khi máy chạy bow bật "duyệt từ điện thoại",
/// duyệt / trả lời ngay tại đây. Ghép máy = quét mã QR ở web bow (Cài đặt → Thông báo điện thoại).
///
/// Cấu trúc: MVVM + Riverpod — `src/models` (dữ liệu), `src/services` (FCM, Realtime Database, thông báo, lưu trữ —
/// mỗi service một provider), `src/pages/<màn>/…_vm.dart` (ViewModel = `Notifier`) + `…_page.dart` (View),
/// `src/components` (widget dùng chung), `src/themes`.
///
/// App chạy nền / đã tắt: hệ điều hành tự hiện thông báo (FCM gửi kèm khối `notification`). App đang mở: iOS vẫn
/// hiện + kêu; Android thì không — app tự dựng thông báo (NotificationService), kèm nút duyệt khi đó là một thẻ.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Một container cho cả app: service khởi động ở đây cũng chính là service các ViewModel dùng về sau.
  final container = ProviderContainer();
  // Giấy phép của hai phông chữ đi kèm app (theme brutal) — hiện ở Cài đặt → Giấy phép mã nguồn mở.
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in const [
      ('Space Grotesk', 'OFL-SpaceGrotesk.txt'),
      ('Space Mono', 'OFL-SpaceMono.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
  // Theme người dùng đã chọn: nạp trước khung hình đầu tiên (không phụ thuộc Firebase).
  await container.read(appearanceVmProvider.notifier).load();
  await container.read(unlockMinutesProvider.notifier).load();
  String? firebaseError;
  try {
    // Không truyền options: đọc cấu hình native do `flutterfire configure` đặt (google-services.json /
    // GoogleService-Info.plist). Android cần cấu hình native để hiện thông báo cả khi app đã tắt hẳn.
    await Firebase.initializeApp();
    // Thông báo tới lúc app đang nền / đã tắt: nâng nó thành bản có nút duyệt.
    FirebaseMessaging.onBackgroundMessage(pushInBackground);
    await container
        .read(notificationServiceProvider)
        .init(onBackgroundResponse: notificationActionInBackground);
    // Widget màn hình chính: cú chạm vào nút của nó cũng chạy nền.
    await container
        .read(homeWidgetServiceProvider)
        .init(widgetTappedInBackground);
  } catch (e) {
    firebaseError = '$e';
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: BowNotifyApp(firebaseError: firebaseError),
    ),
  );
}
