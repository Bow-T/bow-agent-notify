import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thông báo đẩy (FCM): xin quyền, nghe tin tới, đăng ký / bỏ đăng ký topic của máy đã ghép.
class PushService {
  const PushService();

  static const _timeout = Duration(seconds: 20);

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// Dự án Firebase mà bản app này build cho — mã ghép thuộc dự án khác thì sẽ không nhận được gì.
  String get projectId => Firebase.app().options.projectId;

  /// Xin quyền thông báo. `true` = người dùng đã TỪ CHỐI.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    // iOS: cho thông báo hiện + kêu cả khi app đang mở. Android không có lựa chọn này — app tự dựng thông báo
    // (NotificationService.handlePush).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.denied;
  }

  /// Tin tới lúc app đang mở.
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  /// Người dùng bấm vào một thông báo (do hệ điều hành dựng) để mở app.
  Stream<RemoteMessage> get onOpened => FirebaseMessaging.onMessageOpenedApp;

  /// Mã nhận thông báo của máy vừa ĐỔI (cài lại app, khôi phục dữ liệu, Google xoay mã). Đăng ký topic đi theo mã cũ
  /// ⇒ phải đăng ký lại, không thì máy vẫn hiện "đã ghép" mà không bao giờ nhận gì.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> subscribe(String topic) =>
      _messaging.subscribeToTopic(topic).timeout(_timeout);

  Future<void> unsubscribe(String topic) =>
      _messaging.unsubscribeFromTopic(topic).timeout(_timeout);
}

final pushServiceProvider = Provider<PushService>((ref) => const PushService());
