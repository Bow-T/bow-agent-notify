import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_action.dart';
import '../models/card_ref.dart';
import '../models/pairing.dart';
import '../models/pending_card.dart';
import '../utils/l10n.dart';
import 'pairing_store.dart';
import 'remote_service.dart';

bool get _android => defaultTargetPlatform == TargetPlatform.android;

/// Kênh thông báo do MainActivity tạo (mỗi kênh một âm). Tên phải khớp bên Kotlin — khác tên là kênh bị đổi tên.
const _channels = {
  'bow_ask': 'Bow · đang chờ bạn',
  'bow_done': 'Bow · đã xong',
  'bow_fail': 'Bow · lượt chạy lỗi',
};

const _shownKey = 'shownCards';
const _shownMaxAge = Duration(hours: 24);

/// Thông báo CÓ NÚT DUYỆT (Android): thông báo đẩy của một thẻ mang mã thẻ; app tra đúng thẻ đó trên Realtime Database,
/// rồi THAY thông báo hệ điều hành vừa hiện (cùng tag) bằng bản có lệnh cần duyệt + nút Cho phép / Từ chối. Bấm nút là
/// gửi quyết định luôn, không mở app — kể cả khi app đã tắt.
///
/// Vì sao thay chứ không tự hiện từ đầu: thông báo do hệ điều hành dựng thì tới được cả khi máy không cho app chạy nền;
/// bản có nút là phần NÂNG CẤP khi app chạy được. App không chạy nền được thì vẫn còn thông báo thường, bấm vào là mở app.
///
/// Thao tác RỦI RO không có nút "Cho phép" trên thông báo: nó phải qua vân tay, mà vân tay cần mở app.
///
/// Thông báo "đã xong" cũng có nút khi bow mời vài câu trả lời nhanh ("push", "tiếp", "commit/push" — thẻ `reply`):
/// bấm một câu là tab trên máy gửi đúng câu đó, lượt mới chạy tiếp mà không cần về máy.
/// iOS chưa có nút trên thông báo (cần một phần mở rộng native để giải mã nội dung) — mọi thứ ở đây chỉ chạy trên Android.
class NotificationService {
  NotificationService(this._remote, this._store);

  final RemoteService _remote;
  final PairingStore _store;
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Màn chính nghe cái này để đọc lại thẻ chờ khi người dùng bấm vào một thông báo.
  final opened = ValueNotifier<int>(0);

  /// Ghi nhớ thông báo [tag] đang mang nút của thẻ [cardId]; `null` = thông báo dưới tag đó không còn là thẻ nào.
  Future<void> _remember(String tag, String? cardId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // isolate nền và màn chính ghi chung
    final shown = decodeShown(prefs.getString(_shownKey));
    final now = DateTime.now().millisecondsSinceEpoch;
    if (cardId == null) {
      if (shown.remove(tag) == null) return;
    } else {
      shown[tag] = (id: cardId, at: now);
      shown.removeWhere((_, v) => now - v.at > _shownMaxAge.inMilliseconds);
    }
    await prefs.setString(_shownKey, encodeShown(shown));
  }

  /// Gỡ thông báo có nút của những thẻ không còn chờ. [live] = mã các thẻ còn chờ, đọc được từ lúc [asOf].
  Future<void> dismissHandledCards(Set<String> live, DateTime asOf) async {
    if (!_android) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final shown = decodeShown(prefs.getString(_shownKey));
    final gone = staleTags(shown, live, asOf.millisecondsSinceEpoch);
    if (gone.isEmpty) return;
    for (final tag in gone) {
      await _plugin.cancel(id: 0, tag: tag);
      shown.remove(tag);
    }
    await prefs.setString(_shownKey, encodeShown(shown));
  }

  AndroidNotificationDetails _details(
    String channel, {
    required String tag,
    String? bigText,
    String? subText,
    List<CardAction> actions = const [],
    bool alert = true,
  }) => AndroidNotificationDetails(
    channel,
    _channels[channel] ?? _channels['bow_ask']!,
    icon: 'ic_stat_bow',
    color: const Color(0xFF007AFF),
    importance: Importance.high,
    priority: Priority.high,
    tag: tag,
    subText: subText,
    // Đã có một thông báo cùng tag vừa kêu (bản hệ điều hành dựng) thì bản thay thế không kêu lần nữa.
    onlyAlertOnce: !alert,
    // Màn hình khoá: không hiện lệnh, không hiện nút — phải mở khoá mới thấy / mới duyệt được.
    visibility: NotificationVisibility.private,
    styleInformation: bigText == null ? null : BigTextStyleInformation(bigText),
    actions: [
      for (final a in actions)
        AndroidNotificationAction(
          a.id,
          a.title,
          showsUserInterface: a.opensApp,
        ),
    ],
  );

  /// Hiện (hoặc thay) thông báo của một thẻ, kèm nút.
  Future<void> _showCard(
    PendingCard card,
    String tag, {
    required bool alert,
  }) async {
    await _remember(tag, card.id);
    await _plugin.show(
      id: 0,
      title: card.label.isEmpty ? t('Tác vụ', 'Task') : card.label,
      body: card.text,
      notificationDetails: NotificationDetails(
        android: _details(
          // Lời mời trả lời đi cùng thông báo "đã xong" — giữ kênh (và âm) của nó.
          card.kind == 'reply' ? 'bow_done' : 'bow_ask',
          tag: tag,
          bigText: card.text,
          subText: [
            if (card.risky) t('RỦI RO', 'RISKY'),
            card.pairing.host,
          ].join(' · '),
          actions: cardActions(card),
          alert: alert,
        ),
      ),
      payload: encodeRef((
        topic: card.pairing.topic,
        port: card.port,
        id: card.id,
        tag: tag,
      )),
    );
  }

  /// Các máy đã ghép CÓ khoá duyệt; có [topic] thì chỉ máy đó. Rỗng = điện thoại này không duyệt được cho máy gửi (ghép từ
  /// trước khi bật duyệt từ điện thoại, hoặc đã bỏ ghép).
  Future<List<Pairing>> _approvers(String? topic) async => [
    for (final pairing in await _store.load(fresh: true))
      if (pairing.canApprove && (topic == null || pairing.topic == topic))
        pairing,
  ];

  /// Một thông báo đẩy vừa tới. [foreground] = app đang mở (hệ điều hành KHÔNG tự hiện gì) hay đang nền / đã tắt (hệ điều
  /// hành đã hiện bản thường, giờ nâng cấp nó).
  Future<void> handlePush(
    RemoteMessage message, {
    required bool foreground,
  }) async {
    if (!_android) return;
    final note = message.notification;
    final tag = message.data['tag'] as String? ?? note?.android?.tag;
    // `id` = thẻ chờ duyệt / câu hỏi; `rid` = lời mời trả lời đi kèm thông báo "đã xong".
    final id = message.data['id'] ?? message.data['rid'];
    final port = message.data['port'];
    if (tag == null) return;
    if (id is String && port is String) {
      // Thông báo gửi theo topic ⇒ `from` cho biết máy nào gửi.
      final from = message.from ?? '';
      final topic = from.startsWith('/topics/') ? from.substring(8) : null;
      try {
        final approvers = await _approvers(topic);
        for (final pairing in approvers) {
          final card = await _remote.fetchCard(pairing, port, id);
          if (card != null) return _showCard(card, tag, alert: foreground);
        }
        // Biết chắc máy gửi + có khoá của nó mà thẻ không còn ⇒ đã được xử lý trước khi thông báo tới: gỡ bản thường đang
        // nằm trong khay (app đang mở thì chưa hiện gì). Không chắc (không có khoá, không rõ máy gửi) thì để nguyên.
        // Lời mời trả lời đã rút thì KHÔNG gỡ: "lượt đã xong" vẫn là tin đúng, chỉ là không còn nút.
        if (topic != null &&
            approvers.isNotEmpty &&
            message.data['id'] is String) {
          if (!foreground) await _plugin.cancel(id: 0, tag: tag);
          return _remember(tag, null);
        }
      } catch (_) {
        // Mất mạng / không đọc được thẻ: để nguyên thông báo thường.
      }
    }
    // Từ đây thông báo dưới tag này là bản thường (xong / lỗi / thẻ không tra được) — không còn nút của thẻ nào.
    await _remember(tag, null);
    if (!foreground || note == null) return;
    final channel = note.android?.channelId ?? 'bow_ask';
    await _plugin.show(
      id: 0,
      title: note.title,
      body: note.body,
      notificationDetails: NotificationDetails(
        android: _details(
          _channels.containsKey(channel) ? channel : 'bow_ask',
          tag: tag,
        ),
      ),
    );
  }

  /// Người dùng bấm vào thông báo hoặc một nút của nó.
  Future<void> handleResponse(NotificationResponse response) async {
    final ref = decodeRef(response.payload);
    final actionId = response.actionId;
    if (ref == null || actionId == null || actionId == 'open') {
      opened
          .value++; // bấm vào thân thông báo / nút "Mở": app mở lên, màn chính đọc lại thẻ chờ
      return;
    }
    Future<void> failed(String body) async {
      await _remember(ref.tag, null);
      await _plugin.show(
        id: 0,
        title: t('Bow · chưa gửi được', 'Bow · not sent'),
        body: body,
        notificationDetails: NotificationDetails(
          android: _details('bow_ask', tag: ref.tag),
        ),
      );
    }

    try {
      final approvers = await _approvers(ref.topic);
      final card = approvers.isEmpty
          ? null
          : await _remote.fetchCard(approvers.first, ref.port, ref.id);
      final reply = card == null ? null : replyForAction(card, actionId);
      if (card == null || reply == null) {
        return failed(
          t(
            'Thẻ này không còn chờ nữa (đã được xử lý ở nơi khác).',
            'This card is no longer waiting (handled elsewhere).',
          ),
        );
      }
      await _remote.sendReply(card, reply);
      await _plugin.cancel(id: 0, tag: ref.tag);
      await _remember(ref.tag, null);
      opened.value++;
    } catch (e) {
      await failed(
        t('Mở app để thử lại. ($e)', 'Open the app to try again. ($e)'),
      );
    }
  }

  /// Gọi một lần lúc app khởi động (và trong mỗi isolate nền trước khi dùng).
  Future<void> init() async {
    if (!_android) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_bow'),
      ),
      onDidReceiveNotificationResponse: handleResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationActionInBackground,
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(
    ref.watch(remoteServiceProvider),
    ref.watch(pairingStoreProvider),
  ),
);

/// Phần chạy NỀN là một isolate riêng, không có cây widget ⇒ tự dựng một `ProviderContainer` để lấy service (cùng
/// các provider với app), xong việc thì huỷ.
Future<void> _inBackground(
  Future<void> Function(NotificationService service) run,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final container = ProviderContainer();
  try {
    await run(container.read(notificationServiceProvider));
  } finally {
    container.dispose();
  }
}

/// Nút trên thông báo được bấm lúc app KHÔNG mở — chạy trong một isolate nền riêng.
@pragma('vm:entry-point')
Future<void> notificationActionInBackground(NotificationResponse response) =>
    _inBackground((service) => service.handleResponse(response));

/// Thông báo đẩy tới lúc app đang nền / đã tắt — cũng một isolate nền riêng (đăng ký ở `main`).
@pragma('vm:entry-point')
Future<void> pushInBackground(RemoteMessage message) =>
    _inBackground((service) async {
      await service.init();
      await service.handlePush(message, foreground: false);
    });
