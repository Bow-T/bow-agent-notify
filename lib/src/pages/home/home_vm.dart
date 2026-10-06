import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pairing.dart';
import '../../models/pending_card.dart';
import '../../models/received.dart';
import '../../services/biometric_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/notification_service.dart';
import '../../services/pairing_store.dart';
import '../../services/push_service.dart';
import '../../services/remote_service.dart';
import '../../utils/l10n.dart';

/// Trạng thái màn chính — View chỉ đọc cái này.
@immutable
class HomeState {
  const HomeState({
    this.pairings = const [],
    this.pending = const [],
    this.sending = const {},
    this.recent = const [],
    this.notifyDenied = false,
    this.busy = false,
    this.canPinWidget = false,
    this.notListening = const {},
  });

  final List<Pairing> pairings;

  /// Thẻ đang chờ trên các máy cho duyệt từ điện thoại — cũ nhất trước.
  final List<PendingCard> pending;

  /// Thẻ đang gửi quyết định (khoá nút).
  final Set<String> sending;

  /// Thông báo tới lúc app đang mở — mới nhất trước.
  final List<Received> recent;

  /// Người dùng đã tắt quyền thông báo của app.
  final bool notifyDenied;

  /// Đang ghép một máy (khoá nút quét / dán mã).
  final bool busy;

  /// Launcher của máy cho app tự đề nghị ghim widget ra màn hình chính.
  final bool canPinWidget;

  /// Topic của những máy đã ghép mà lần đăng ký nhận thông báo gần nhất HỎNG — máy đó hiện "đã ghép" nhưng thông báo
  /// của nó sẽ không tới cho tới khi đăng ký lại được.
  final Set<String> notListening;

  HomeState copyWith({
    List<Pairing>? pairings,
    List<PendingCard>? pending,
    Set<String>? sending,
    List<Received>? recent,
    bool? notifyDenied,
    bool? busy,
    bool? canPinWidget,
    Set<String>? notListening,
  }) => HomeState(
    pairings: pairings ?? this.pairings,
    pending: pending ?? this.pending,
    sending: sending ?? this.sending,
    recent: recent ?? this.recent,
    notifyDenied: notifyDenied ?? this.notifyDenied,
    busy: busy ?? this.busy,
    canPinWidget: canPinWidget ?? this.canPinWidget,
    notListening: notListening ?? this.notListening,
  );
}

/// Kết quả chẩn đoán của một máy đã ghép: hai chặng mà thông báo / thẻ phải đi qua.
typedef MachineCheck = ({
  Pairing pairing,

  /// Đăng ký nhận thông báo đẩy của máy này được (FCM).
  bool subscribed,

  /// Đọc được thẻ chờ từ database; `null` = máy chỉ gửi thông báo (chưa bật duyệt từ điện thoại) nên không có gì để đọc.
  bool? database,

  /// Lỗi của lần đọc database (rỗng = không lỗi).
  String error,
});

/// ViewModel của màn chính: máy đã ghép, thẻ đang chờ, quyết định gửi đi. Mọi thao tác trả về câu cần nói lại với
/// người dùng (`null` = không có gì để nói) — View chỉ việc hiện, không tự suy luận.
class HomeVm extends Notifier<HomeState> {
  static const _pollEvery = Duration(seconds: 4);

  /// Thẻ vừa trả lời: ẩn ngần này chờ máy chạy bow áp + gỡ. Quá hạn mà còn đó thì hiện lại (bow chưa nhận).
  static const _hideAnswered = Duration(seconds: 15);

  final Map<String, DateTime> _answeredAt = {};
  Timer? _timer;

  PushService get _push => ref.read(pushServiceProvider);
  RemoteService get _remote => ref.read(remoteServiceProvider);
  PairingStore get _store => ref.read(pairingStoreProvider);
  NotificationService get _notifications =>
      ref.read(notificationServiceProvider);
  HomeWidgetService get _widget => ref.read(homeWidgetServiceProvider);

  @override
  HomeState build() {
    final push = _push;
    final notifications = _notifications;
    void refresh() => unawaited(refreshPending());
    final subs = [
      push.onMessage.listen(_onMessage),
      // Bấm vào thông báo để mở app: đọc ngay thẻ đang chờ.
      push.onOpened.listen((_) => refresh()),
      push.onTokenRefresh.listen((_) => unawaited(_resubscribe())),
    ];
    // Bấm vào một thông báo app tự dựng (hoặc vừa duyệt bằng nút trên thông báo): cũng đọc lại ngay.
    notifications.opened.addListener(refresh);
    ref.onDispose(() {
      _timer?.cancel();
      for (final sub in subs) {
        unawaited(sub.cancel());
      }
      notifications.opened.removeListener(refresh);
    });
    unawaited(_start());
    return const HomeState();
  }

  Future<void> _start() async {
    final saved = await _store.load();
    final denied = await _push.requestPermission();
    final canPin = await _widget.canPin();
    if (!ref.mounted) return;
    state = state.copyWith(
      pairings: saved,
      notifyDenied: denied,
      canPinWidget: canPin,
    );
    _watchPending();
    unawaited(_resubscribe());
  }

  /// Đăng ký lại topic của MỌI máy đã ghép — mỗi lần app khởi động và mỗi lần mã nhận thông báo của máy đổi.
  ///
  /// Đăng ký topic gắn với mã nhận thông báo của lần cài hiện tại; ghép máy chỉ đăng ký MỘT lần. Cài lại app, khôi phục
  /// dữ liệu hay Google xoay mã là mất đăng ký trong khi danh sách máy vẫn còn: app ghi "đang nghe", mở app vẫn thấy
  /// thẻ (đọc thẳng từ database), nhưng không thông báo nào tới nữa. Đăng ký lại thì vô hại (đăng ký hai lần như một).
  Future<void> _resubscribe() async {
    final failed = <String>{};
    for (final pairing in state.pairings) {
      try {
        await _push.subscribe(pairing.topic);
      } catch (_) {
        failed.add(pairing.topic); // mất mạng: lần mở app sau thử lại
      }
    }
    if (!ref.mounted) return;
    // Máy đã bị bỏ ghép trong lúc chờ thì không tính.
    final topics = {for (final pairing in state.pairings) pairing.topic};
    state = state.copyWith(notListening: failed.intersection(topics));
  }

  /// Đề nghị ghim một widget ra màn hình chính (launcher hiện hộp xác nhận của nó): thẻ "Chờ bạn duyệt", hoặc viên
  /// thuốc "Trạng thái".
  Future<void> pinWidget({bool status = false}) => _widget.pin(status: status);

  /// App trở lại trước mặt: đọc thẻ chờ ngay và hỏi lại theo nhịp.
  void resumed() => _watchPending();

  /// App khuất: thôi hỏi — thông báo đẩy sẽ gọi dậy.
  void paused() {
    _timer?.cancel();
    _timer = null;
  }

  /// Đọc thẻ chờ ngay, rồi hỏi lại mỗi 4 giây chừng nào app còn ở trước mặt và có máy cho duyệt.
  void _watchPending() {
    paused();
    unawaited(refreshPending());
    if (!state.pairings.any((p) => p.canApprove)) return;
    _timer = Timer.periodic(_pollEvery, (_) => unawaited(refreshPending()));
  }

  Future<void> refreshPending() async {
    final sources = state.pairings.where((p) => p.canApprove).toList();
    final asOf = DateTime.now();
    var complete = true;
    // Một máy không đọc được (mất mạng) không được làm mất thẻ của máy khác.
    final results = await Future.wait(
      sources.map(
        (p) => _remote.fetchPending(p).catchError((Object _) {
          complete = false;
          return <PendingCard>[];
        }),
      ),
    );
    if (!ref.mounted) return;
    final now = DateTime.now();
    _answeredAt.removeWhere((_, at) => now.difference(at) > _hideAnswered);
    final cards = [
      for (final list in results)
        for (final card in list)
          if (!_answeredAt.containsKey(card.id)) card,
    ];
    if (!listEquals(
      [for (final card in cards) card.id],
      [for (final card in state.pending) card.id],
    )) {
      state = state.copyWith(pending: cards);
    }
    // Thẻ đã xử lý (vừa bấm trong app, hoặc ở web) thì gỡ luôn thông báo có nút của nó, và widget màn hình chính vẽ
    // lại theo danh sách vừa đọc. Chỉ khi đọc được MỌI máy — đọc hụt một máy mà gỡ là mất thẻ còn đang chờ.
    if (complete) {
      unawaited(
        _notifications.dismissHandledCards({
          for (final card in cards) card.id,
        }, asOf),
      );
      unawaited(_widget.show(cards, state.pairings.length));
    }
  }

  /// Gửi quyết định cho một thẻ: `{allow: bool}`, `{answers: {...} | null}` hoặc `{say: câu}`.
  ///
  /// "Cho phép" một thao tác RỦI RO phải qua vân tay / khuôn mặt / mật mã máy; máy không xác thực được thì hỏi lại
  /// bằng [askRisky] (hộp xác nhận của View). Không qua được thì không gửi gì.
  Future<String?> decide(
    PendingCard card,
    Map<String, Object?> reply, {
    required Future<bool> Function() askRisky,
  }) async {
    if (state.sending.contains(card.id)) return null;
    if (card.risky && reply['allow'] == true) {
      final confirmed =
          await ref
              .read(biometricServiceProvider)
              .confirm(
                t(
                  'Xác nhận để cho phép thao tác rủi ro trên ${card.pairing.host}',
                  'Confirm to allow a risky action on ${card.pairing.host}',
                ),
              ) ??
          await askRisky();
      if (!confirmed || !ref.mounted) return null;
    }
    state = state.copyWith(sending: {...state.sending, card.id});
    try {
      await _remote.sendReply(card, reply);
      _answeredAt[card.id] = DateTime.now();
      if (!ref.mounted) return null;
      state = state.copyWith(
        pending: [
          for (final c in state.pending)
            if (c.id != card.id) c,
        ],
      );
      unawaited(
        refreshPending(),
      ); // gỡ luôn thông báo có nút của thẻ vừa trả lời
      return null;
    } catch (e) {
      return t(
        'Không gửi được ($e). Thẻ này có thể đã được trả lời, hoặc bow không còn chạy.',
        'Could not send ($e). The card may already be answered, or bow is no longer running.',
      );
    } finally {
      if (ref.mounted) {
        state = state.copyWith(
          sending: {
            for (final id in state.sending)
              if (id != card.id) id,
          },
        );
      }
    }
  }

  /// Tin tới lúc app đang mở: ghi vào "Vừa nhận", và trên Android tự dựng thông báo (đúng kênh ⇒ đúng âm) vì hệ
  /// điều hành không hiện gì khi app ở trước mặt.
  void _onMessage(RemoteMessage message) {
    final note = message.notification;
    if (note == null) return;
    unawaited(refreshPending());
    unawaited(_notifications.handlePush(message, foreground: true));
    final Received event = (
      kind: message.data['kind'] as String? ?? '',
      title: note.title ?? '',
      body: note.body ?? '',
      at: DateTime.now(),
    );
    unawaited(_widget.noteEvent(event));
    state = state.copyWith(recent: [event, ...state.recent]);
  }

  /// Ghép với máy trong mã: kiểm dự án Firebase khớp với app, đăng ký topic, rồi mới lưu.
  Future<String?> pair(String? raw) async {
    if (raw == null) return null;
    final pairing = Pairing.parse(raw);
    if (pairing == null) {
      return t(
        'Đây không phải mã ghép của bow.',
        'This is not a bow pairing code.',
      );
    }
    final appProject = _push.projectId;
    if (pairing.projectId != appProject) {
      return t(
        'Mã ghép thuộc dự án Firebase "${pairing.projectId}", còn app này build cho "$appProject" — sẽ không nhận được gì. Build lại app với đúng dự án.',
        'This code belongs to Firebase project "${pairing.projectId}" but the app was built for "$appProject" — nothing would arrive. Rebuild the app for that project.',
      );
    }
    final pairings = state.pairings;
    final existing = pairings.indexWhere((p) => p.topic == pairing.topic);
    if (existing >= 0) {
      if (pairings[existing].uri == pairing.uri) {
        return t('Máy này đã ghép rồi.', 'Already paired with this machine.');
      }
      // Cùng máy nhưng mã MỚI — web vừa bật / tắt "duyệt từ điện thoại" (mã có thêm / mất khoá) hay đổi tên máy:
      // thay bản đã lưu. Topic không đổi nên khỏi đăng ký lại; không làm thế thì phải bỏ ghép rồi quét lại mới có khoá.
      await _setPairings([...pairings]..[existing] = pairing);
      return pairing.canApprove
          ? t(
              'Đã cập nhật ${pairing.host}: giờ duyệt được từ điện thoại này.',
              'Updated ${pairing.host}: you can now approve from this phone.',
            )
          : t(
              'Đã cập nhật ${pairing.host}: chỉ nhận thông báo.',
              'Updated ${pairing.host}: notifications only.',
            );
    }
    state = state.copyWith(busy: true);
    try {
      await _push.subscribe(pairing.topic);
      await _setPairings([...state.pairings, pairing]);
      return t(
        'Đã ghép với ${pairing.host}. Bấm "Gửi thử" trên web để kiểm.',
        'Paired with ${pairing.host}. Press "Send test" on the web to check.',
      );
    } catch (e) {
      // iOS chưa có token APNs (thiếu quyền Push / chạy trên máy ảo không hỗ trợ) là lý do hay gặp nhất.
      return t('Không đăng ký nhận được: $e', 'Could not subscribe: $e');
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// Chẩn đoán (Cài đặt → Chẩn đoán): thử lại hai chặng của TỪNG máy — đăng ký nhận thông báo, đọc thẻ chờ — và báo
  /// chặng nào hỏng. Cũng cập nhật luôn dấu "chưa đăng ký được" của các máy.
  Future<List<MachineCheck>> diagnose() async {
    final results = <MachineCheck>[];
    for (final pairing in state.pairings) {
      var subscribed = true;
      try {
        await _push.subscribe(pairing.topic);
      } catch (_) {
        subscribed = false;
      }
      bool? database;
      var error = '';
      if (pairing.canApprove) {
        try {
          await _remote.fetchPending(pairing);
          database = true;
        } catch (e) {
          database = false;
          error = '$e';
        }
      }
      results.add((
        pairing: pairing,
        subscribed: subscribed,
        database: database,
        error: error,
      ));
    }
    if (ref.mounted) {
      // Máy đã bị bỏ ghép trong lúc chờ thì không tính.
      final topics = {for (final pairing in state.pairings) pairing.topic};
      state = state.copyWith(
        notListening: {
          for (final check in results)
            if (!check.subscribed && topics.contains(check.pairing.topic))
              check.pairing.topic,
        },
      );
    }
    return results;
  }

  /// Bỏ ghép một máy (View đã hỏi lại người dùng). Bỏ đăng ký topic TRƯỚC — không bỏ được thì giữ nguyên, không thì
  /// máy biến khỏi danh sách mà điện thoại vẫn nhận thông báo của nó.
  Future<String?> unpair(Pairing pairing) async {
    try {
      await _push.unsubscribe(pairing.topic);
    } catch (e) {
      return t(
        'Không bỏ đăng ký được (cần mạng): $e',
        'Could not unsubscribe (needs network): $e',
      );
    }
    await _setPairings([
      for (final p in state.pairings)
        if (p.topic != pairing.topic) p,
    ]);
    if (ref.mounted) {
      state = state.copyWith(
        notListening: {
          for (final topic in state.notListening)
            if (topic != pairing.topic) topic,
        },
      );
    }
    return null;
  }

  Future<void> _setPairings(List<Pairing> pairings) async {
    state = state.copyWith(pairings: pairings);
    await _store.save(pairings);
    if (ref.mounted) _watchPending();
  }
}

final homeVmProvider = NotifierProvider<HomeVm, HomeState>(HomeVm.new);
