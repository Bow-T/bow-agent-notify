import 'dart:convert';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pairing.dart';
import 'remote.dart';
import 'store.dart';

/// Thông báo CÓ NÚT DUYỆT (Android): thông báo đẩy của một thẻ mang mã thẻ; app tra đúng thẻ đó trên Realtime Database,
/// rồi THAY thông báo hệ điều hành vừa hiện (cùng tag) bằng bản có lệnh cần duyệt + nút Cho phép / Từ chối. Bấm nút là
/// gửi quyết định luôn, không mở app — kể cả khi app đã tắt.
///
/// Vì sao thay chứ không tự hiện từ đầu: thông báo do hệ điều hành dựng thì tới được cả khi máy không cho app chạy nền;
/// bản có nút là phần NÂNG CẤP khi app chạy được. App không chạy nền được thì vẫn còn thông báo thường, bấm vào là mở app.
///
/// Thao tác RỦI RO không có nút "Cho phép" trên thông báo: nó phải qua vân tay, mà vân tay cần mở app.
/// iOS chưa có nút trên thông báo (cần một phần mở rộng native để giải mã nội dung) — mọi thứ ở đây chỉ chạy trên Android.

final _plugin = FlutterLocalNotificationsPlugin();
bool get _android => defaultTargetPlatform == TargetPlatform.android;

String _t(String vi, String en) =>
    PlatformDispatcher.instance.locale.languageCode == 'vi' ? vi : en;

/// Kênh thông báo do MainActivity tạo (mỗi kênh một âm). Tên phải khớp bên Kotlin — khác tên là kênh bị đổi tên.
const _channels = {
  'bow_ask': 'Bow · đang chờ bạn',
  'bow_done': 'Bow · đã xong',
  'bow_fail': 'Bow · lượt chạy lỗi',
};

/// Màn chính nghe cái này để đọc lại thẻ chờ khi người dùng bấm vào một thông báo.
final notificationOpened = ValueNotifier<int>(0);

/// Thứ gắn theo thông báo để nút bấm biết đang nói tới thẻ nào. CHỈ là mã định danh — nội dung thẻ (và cờ rủi ro) luôn
/// được đọc lại từ bản mã của server lúc bấm, không tin thứ nằm trong thông báo.
typedef CardRef = ({String topic, String port, String id, String tag});

String encodeRef(CardRef ref) =>
    jsonEncode({'t': ref.topic, 'p': ref.port, 'i': ref.id, 'g': ref.tag});

CardRef? decodeRef(String? payload) {
  try {
    final json = jsonDecode(payload ?? '');
    if (json is! Map) return null;
    final {'t': topic, 'p': port, 'i': id, 'g': tag} = json;
    if (topic is! String ||
        port is! String ||
        id is! String ||
        tag is! String) {
      return null;
    }
    return (topic: topic, port: port, id: id, tag: tag);
  } catch (_) {
    return null;
  }
}

/// Thông báo CÓ NÚT đang nằm trong khay: tag → mã thẻ + lúc hiện (mili-giây). Trên Android plugin không trả lại thứ gắn
/// theo một thông báo đang hiện, nên phải tự nhớ — để gỡ thông báo của thẻ đã được xử lý ở nơi khác (trong app, trên web):
/// không gỡ thì hai nút của nó nằm lại, bấm vào chỉ nhận được câu "thẻ không còn chờ".
typedef ShownCards = Map<String, ({String id, int at})>;

const _shownKey = 'shownCards';
const _shownMaxAge = Duration(hours: 24);

ShownCards decodeShown(String? text) {
  try {
    final json = jsonDecode(text ?? '');
    if (json is! Map) return {};
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (key is String &&
            value is Map &&
            value['i'] is String &&
            value['a'] is int)
          key: (id: value['i'] as String, at: value['a'] as int),
    };
  } catch (_) {
    return {};
  }
}

String encodeShown(ShownCards shown) => jsonEncode({
  for (final MapEntry(:key, :value) in shown.entries)
    key: {'i': value.id, 'a': value.at},
});

/// Tag của những thông báo có nút cần gỡ: thẻ của nó không còn trong [live]. Chỉ xét thông báo hiện TRƯỚC [asOf] (lúc
/// bắt đầu đọc danh sách thẻ) — thông báo hiện sau đó là của thẻ mà lần đọc này chưa kịp thấy.
List<String> staleTags(ShownCards shown, Set<String> live, int asOf) => [
  for (final MapEntry(:key, :value) in shown.entries)
    if (value.at < asOf && !live.contains(value.id)) key,
];

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

/// Một nút trên thông báo. `opensApp` = bấm là mở app (không gửi gì).
typedef CardAction = ({String id, String title, bool opensApp});

/// Câu hỏi "gọn" trả lời được ngay trên thông báo: đúng một câu, chọn một, tối đa ba lựa chọn (Android hiện tối đa ba nút).
Question? _quickQuestion(PendingCard card) {
  if (card.kind != 'question' || card.questions.length != 1) return null;
  final q = card.questions.single;
  return !q.multiSelect && q.options.isNotEmpty && q.options.length <= 3
      ? q
      : null;
}

/// Các nút của một thẻ.
List<CardAction> cardActions(PendingCard card) {
  if (card.kind == 'approval') {
    return [
      card.risky
          ? (
              id: 'open',
              title: _t('Mở để duyệt', 'Open to approve'),
              opensApp: true,
            )
          : (id: 'allow', title: _t('Cho phép', 'Allow'), opensApp: false),
      (id: 'deny', title: _t('Từ chối', 'Deny'), opensApp: false),
    ];
  }
  final q = _quickQuestion(card);
  if (q == null) {
    return [
      (
        id: 'open',
        title: _t('Mở để trả lời', 'Open to answer'),
        opensApp: true,
      ),
    ];
  }
  return [
    for (final (i, option) in q.options.indexed)
      (id: 'opt:$i', title: option.label, opensApp: false),
  ];
}

/// Quyết định ứng với nút [actionId] của [card]; `null` = nút này không được gửi gì (kể cả khi mã nút bị giả):
/// thẻ rủi ro KHÔNG BAO GIỜ được "cho phép" từ thông báo.
Map<String, Object?>? replyForAction(PendingCard card, String actionId) {
  if (card.kind == 'approval') {
    if (actionId == 'deny') return {'allow': false};
    if (actionId == 'allow' && !card.risky) return {'allow': true};
    return null;
  }
  final q = _quickQuestion(card);
  final index = actionId.startsWith('opt:')
      ? int.tryParse(actionId.substring(4))
      : null;
  if (q == null || index == null || index < 0 || index >= q.options.length) {
    return null;
  }
  return {
    'answers': {q.question: q.options[index].label},
  };
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
      AndroidNotificationAction(a.id, a.title, showsUserInterface: a.opensApp),
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
    title: card.label.isEmpty ? _t('Tác vụ', 'Task') : card.label,
    body: card.text,
    notificationDetails: NotificationDetails(
      android: _details(
        'bow_ask',
        tag: tag,
        bigText: card.text,
        subText: [
          if (card.risky) _t('RỦI RO', 'RISKY'),
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
  for (final pairing in await loadPairings(fresh: true))
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
  final id = message.data['id'];
  final port = message.data['port'];
  if (tag == null) return;
  if (id is String && port is String) {
    // Thông báo gửi theo topic ⇒ `from` cho biết máy nào gửi.
    final from = message.from ?? '';
    final topic = from.startsWith('/topics/') ? from.substring(8) : null;
    try {
      final approvers = await _approvers(topic);
      for (final pairing in approvers) {
        final card = await fetchCard(pairing, port, id);
        if (card != null) return _showCard(card, tag, alert: foreground);
      }
      // Biết chắc máy gửi + có khoá của nó mà thẻ không còn ⇒ đã được xử lý trước khi thông báo tới: gỡ bản thường đang
      // nằm trong khay (app đang mở thì chưa hiện gì). Không chắc (không có khoá, không rõ máy gửi) thì để nguyên.
      if (topic != null && approvers.isNotEmpty) {
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
Future<void> _handleResponse(NotificationResponse response) async {
  final ref = decodeRef(response.payload);
  final actionId = response.actionId;
  if (ref == null || actionId == null || actionId == 'open') {
    notificationOpened
        .value++; // bấm vào thân thông báo / nút "Mở": app mở lên, màn chính đọc lại thẻ chờ
    return;
  }
  Future<void> failed(String body) async {
    await _remember(ref.tag, null);
    await _plugin.show(
      id: 0,
      title: _t('Bow · chưa gửi được', 'Bow · not sent'),
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
        : await fetchCard(approvers.first, ref.port, ref.id);
    final reply = card == null ? null : replyForAction(card, actionId);
    if (card == null || reply == null) {
      return failed(
        _t(
          'Thẻ này không còn chờ nữa (đã được xử lý ở nơi khác).',
          'This card is no longer waiting (handled elsewhere).',
        ),
      );
    }
    await sendReply(card, reply);
    await _plugin.cancel(id: 0, tag: ref.tag);
    await _remember(ref.tag, null);
    notificationOpened.value++;
  } catch (e) {
    await failed(
      _t('Mở app để thử lại. ($e)', 'Open the app to try again. ($e)'),
    );
  }
}

/// Gọi một lần lúc app khởi động (và trong mỗi isolate nền trước khi dùng).
Future<void> initNotifications() async {
  if (!_android) return;
  await _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_bow'),
    ),
    onDidReceiveNotificationResponse: _handleResponse,
    onDidReceiveBackgroundNotificationResponse: notificationActionInBackground,
  );
}

/// Nút trên thông báo được bấm lúc app KHÔNG mở — chạy trong một isolate nền riêng.
@pragma('vm:entry-point')
Future<void> notificationActionInBackground(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await _handleResponse(response);
}

/// Thông báo đẩy tới lúc app đang nền / đã tắt — cũng một isolate nền riêng (đăng ký ở `main`).
@pragma('vm:entry-point')
Future<void> pushInBackground(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await initNotifications();
  await handlePush(message, foreground: false);
}
