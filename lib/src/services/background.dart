import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_widget_service.dart';
import 'notification_service.dart';

/// Các điểm vào chạy NỀN — mỗi cái là một isolate riêng do hệ điều hành dựng, không có cây widget, không có
/// `ProviderScope` của app. Chúng tự dựng một `ProviderContainer` để lấy đúng các service mà app dùng, xong việc thì huỷ.
Future<void> _inBackground(
  Future<void> Function(ProviderContainer container) run,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final container = ProviderContainer();
  try {
    await run(container);
  } finally {
    container.dispose();
  }
}

/// Thông báo đẩy tới lúc app đang nền / đã tắt (đăng ký ở `main`): nâng thông báo thành bản có nút, rồi làm mới
/// widget màn hình chính.
@pragma('vm:entry-point')
Future<void> pushInBackground(RemoteMessage message) =>
    _inBackground((container) async {
      final notifications = container.read(notificationServiceProvider);
      await notifications.init(
        onBackgroundResponse: notificationActionInBackground,
      );
      await notifications.handlePush(message, foreground: false);
      final widget = container.read(homeWidgetServiceProvider);
      final note = message.notification;
      if (note != null) {
        await widget.noteEvent((
          kind: message.data['kind'] as String? ?? '',
          title: note.title ?? '',
          body: note.body ?? '',
          at: DateTime.now(),
        ));
      }
      await widget.sync();
    });

/// Nút trên thông báo được bấm lúc app KHÔNG mở.
@pragma('vm:entry-point')
Future<void> notificationActionInBackground(NotificationResponse response) =>
    _inBackground((container) async {
      final answered = await container
          .read(notificationServiceProvider)
          .handleResponse(response);
      await container
          .read(homeWidgetServiceProvider)
          .sync(exclude: {?answered});
    });

/// Nút trên widget màn hình chính được bấm.
@pragma('vm:entry-point')
Future<void> widgetTappedInBackground(Uri? uri) => _inBackground(
  (container) => container.read(homeWidgetServiceProvider).handle(uri),
);
