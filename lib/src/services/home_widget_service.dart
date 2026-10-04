import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../models/card_action.dart';
import '../models/pending_card.dart';
import '../models/received.dart';
import '../models/widget_snapshot.dart';
import 'notification_service.dart';
import 'pairing_store.dart';
import 'remote_service.dart';

bool get _android => defaultTargetPlatform == TargetPlatform.android;

/// Widget màn hình chính (Android): "Chờ bạn duyệt" (thẻ + nút) và viên thuốc "Trạng thái". Phần vẽ nằm ở Kotlin
/// (`BowWidgets.kt`); ở đây lo DỮ LIỆU — khi nào đọc lại, ghi gì, và xử lý cú chạm vào nút.
///
/// Widget không tự hỏi mạng theo nhịp (hệ điều hành không cho): nó được làm mới khi app đang mở (màn chính đọc thẻ),
/// khi có thông báo đẩy tới, sau mỗi quyết định, khi người dùng bấm ↻, và mỗi 30 phút do hệ điều hành gọi.
///
/// iOS chưa có widget (cần một target WidgetKit + App Group) — mọi hàm ở đây là rỗng trên iOS.
class HomeWidgetService {
  HomeWidgetService(this._remote, this._store, this._notifications);

  static const _pending = 'dev.bow.bow_notify.PendingWidgetProvider';
  static const _status = 'dev.bow.bow_notify.StatusWidgetProvider';

  final RemoteService _remote;
  final PairingStore _store;
  final NotificationService _notifications;

  /// Gọi một lần lúc app khởi động: đăng ký hàm nhận cú chạm vào nút của widget (chạy ở isolate nền).
  Future<void> init(Future<void> Function(Uri? uri) onTap) async {
    if (!_android) return;
    await _guard(() => HomeWidget.registerInteractivityCallback(onTap));
  }

  /// Máy cho phép app tự đề nghị ghim widget ra màn hình chính (launcher có hỗ trợ).
  Future<bool> canPin() async {
    if (!_android) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mở hộp "thêm widget ra màn hình chính" của launcher: widget "Chờ bạn duyệt", hoặc viên thuốc "Trạng thái".
  Future<void> pin({bool status = false}) => _guard(
    () => HomeWidget.requestPinWidget(
      qualifiedAndroidName: status ? _status : _pending,
    ),
  );

  /// Vẽ lại từ danh sách thẻ đã có trong tay (màn chính vừa đọc) — không gọi mạng.
  Future<void> show(
    List<PendingCard> cards,
    int machines, {
    bool busy = false,
  }) async {
    if (!_android) return;
    await _guard(() async {
      await _write(
        widgetSnapshot(
          cards: cards,
          machines: machines,
          now: DateTime.now(),
          last: await _last(),
          busy: busy,
        ),
      );
    });
  }

  /// Đọc thẻ chờ của mọi máy rồi vẽ lại. [exclude] = thẻ vừa trả lời (máy chạy bow cần vài giây mới gỡ nó).
  /// Đọc hụt một máy thì GIỮ nội dung đang hiện (chỉ gỡ trạng thái "đang gửi") — thà cũ còn hơn báo "không có gì chờ".
  Future<void> sync({Set<String> exclude = const {}}) async {
    if (!_android) return;
    await _guard(() async {
      final pairings = await _store.load(fresh: true);
      final asOf = DateTime.now();
      final cards = <PendingCard>[];
      var complete = true;
      for (final pairing in pairings.where((p) => p.canApprove)) {
        try {
          cards.addAll(await _remote.fetchPending(pairing));
        } catch (_) {
          complete = false;
        }
      }
      if (!complete) {
        await _write({'w_busy': ''});
        return;
      }
      cards.removeWhere((card) => exclude.contains(card.id));
      await _write(
        widgetSnapshot(
          cards: cards,
          machines: pairings.length,
          now: asOf,
          last: await _last(),
        ),
      );
      // Thẻ đã xử lý thì thông báo có nút của nó cũng hết việc.
      await _notifications.dismissHandledCards({
        for (final card in cards) card.id,
      }, asOf);
    });
  }

  /// Ghi "việc gần nhất" (lượt vừa xong / lỗi) — widget hiện nó khi không còn gì chờ.
  Future<void> noteEvent(Received event) async {
    if (!_android || !isWidgetEvent(event.kind)) return;
    await _guard(
      () => Future.wait([
        HomeWidget.saveWidgetData<String>('w_last_kind', event.kind),
        HomeWidget.saveWidgetData<String>('w_last_title', event.title),
        HomeWidget.saveWidgetData<String>('w_last_body', event.body),
        HomeWidget.saveWidgetData<String>(
          'w_last_at',
          '${event.at.millisecondsSinceEpoch}',
        ),
      ]),
    );
  }

  /// Cú chạm vào widget (isolate nền): `bownotify://widget/refresh` hoặc `…/act?t=<topic>&p=<nhánh>&i=<mã thẻ>&a=<nút>`.
  ///
  /// Thứ nằm trong đường dẫn chỉ là MÃ: thẻ thật (và cờ rủi ro) được đọc lại từ bản mã của server rồi mới quyết —
  /// `replyForAction` không bao giờ "cho phép" một thẻ rủi ro, kể cả khi mã nút bị giả.
  Future<void> handle(Uri? uri) async {
    if (uri == null || uri.scheme != 'bownotify' || uri.host != 'widget') {
      return;
    }
    if (uri.path != '/act') return sync();
    final {'t': topic, 'p': port, 'i': id, 'a': action} = {
      for (final key in const ['t', 'p', 'i', 'a'])
        key: uri.queryParameters[key] ?? '',
    };
    await _guard(() => _write({'w_busy': '1'})); // nút biến thành "Đang gửi…"
    var answered = <String>{};
    try {
      final pairings = await _store.load(fresh: true);
      final pairing = pairings
          .where((p) => p.canApprove && p.topic == topic)
          .firstOrNull;
      final card = pairing == null
          ? null
          : await _remote.fetchCard(pairing, port, id);
      final reply = card == null ? null : replyForAction(card, action);
      if (card != null && reply != null) {
        await _remote.sendReply(card, reply);
        answered = {id};
      }
    } catch (_) {
      // Mất mạng / thẻ đã có trả lời: vẽ lại theo sự thật ở dưới.
    }
    await sync(exclude: answered);
  }

  Future<Received?> _last() async {
    final title = await HomeWidget.getWidgetData<String>('w_last_title');
    final at = int.tryParse(
      await HomeWidget.getWidgetData<String>('w_last_at') ?? '',
    );
    if (title == null || title.isEmpty || at == null) return null;
    return (
      kind: await HomeWidget.getWidgetData<String>('w_last_kind') ?? '',
      title: title,
      body: await HomeWidget.getWidgetData<String>('w_last_body') ?? '',
      at: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }

  Future<void> _write(Map<String, String> data) async {
    await Future.wait([
      for (final MapEntry(:key, :value) in data.entries)
        HomeWidget.saveWidgetData<String>(key, value),
    ]);
    await HomeWidget.updateWidget(qualifiedAndroidName: _pending);
    await HomeWidget.updateWidget(qualifiedAndroidName: _status);
  }

  /// Widget hỏng không được làm hỏng app (hay phần xử lý thông báo): nuốt lỗi, chỉ ghi ra log lúc phát triển.
  Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      debugPrint('home widget: $e');
    }
  }
}

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => HomeWidgetService(
    ref.watch(remoteServiceProvider),
    ref.watch(pairingStoreProvider),
    ref.watch(notificationServiceProvider),
  ),
);
