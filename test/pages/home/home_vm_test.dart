import 'dart:async';
import 'dart:convert';

import 'package:bow_notify/src/models/pairing.dart';
import 'package:bow_notify/src/models/pending_card.dart';
import 'package:bow_notify/src/pages/home/home_vm.dart';
import 'package:bow_notify/src/models/received.dart';
import 'package:bow_notify/src/services/biometric_service.dart';
import 'package:bow_notify/src/services/home_widget_service.dart';
import 'package:bow_notify/src/services/notification_service.dart';
import 'package:bow_notify/src/services/pairing_store.dart';
import 'package:bow_notify/src/services/push_service.dart';
import 'package:bow_notify/src/services/remote_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ViewModel của màn chính, chạy với service GIẢ (provider override) — không Firebase, không mạng, không widget.

class FakePush implements PushService {
  final messages = StreamController<RemoteMessage>.broadcast();
  final opened = StreamController<RemoteMessage>.broadcast();
  final tokens = StreamController<String>.broadcast();
  final subscribed = <String>[];
  final unsubscribed = <String>[];
  bool denied = false;
  bool offline = false;

  @override
  String get projectId => 'p1';
  @override
  Future<bool> requestPermission() async => denied;
  @override
  Stream<RemoteMessage> get onMessage => messages.stream;
  @override
  Stream<RemoteMessage> get onOpened => opened.stream;
  @override
  Stream<String> get onTokenRefresh => tokens.stream;
  @override
  Future<void> subscribe(String topic) async {
    if (offline) throw Exception('mất mạng');
    subscribed.add(topic);
  }

  @override
  Future<void> unsubscribe(String topic) async {
    if (offline) throw Exception('mất mạng');
    unsubscribed.add(topic);
  }
}

class FakeStore implements PairingStore {
  FakeStore([this.saved = const []]);
  List<Pairing> saved;

  @override
  Future<List<Pairing>> load({bool fresh = false}) async => saved;
  @override
  Future<void> save(List<Pairing> pairings) async => saved = pairings;
}

class FakeRemote implements RemoteService {
  /// Thẻ đang chờ theo topic của máy.
  final cards = <String, List<PendingCard>>{};

  /// Máy không đọc được (mất mạng).
  final down = <String>{};

  /// Quyết định đã gửi, dạng `<mã thẻ> <json>`.
  final sent = <String>[];
  bool rejectReplies = false;

  @override
  Future<List<PendingCard>> fetchPending(Pairing pairing) async {
    if (down.contains(pairing.topic)) throw Exception('mất mạng');
    return cards[pairing.topic] ?? const [];
  }

  @override
  Future<void> sendReply(PendingCard card, Map<String, Object?> reply) async {
    if (rejectReplies) throw Exception('HTTP 401');
    sent.add('${card.id} ${jsonEncode(reply)}');
  }

  @override
  Future<PendingCard?> fetchCard(Pairing pairing, String port, String id) =>
      throw UnimplementedError();
  @override
  Future<Object?> openCard(Pairing pairing, String id, String blob) =>
      throw UnimplementedError();
  @override
  Future<Object?> openMirror(Pairing pairing, String id, String blob) =>
      throw UnimplementedError();
  @override
  Future<String> sealCommand(Pairing pairing, String id, Object command) =>
      throw UnimplementedError();
  @override
  Future<String> sealReply(Pairing pairing, String id, Object reply) =>
      throw UnimplementedError();
}

class FakeBiometric implements BiometricService {
  /// `null` = máy không xác thực được.
  bool? answer = true;
  int asked = 0;

  @override
  Future<bool?> confirm(String reason) async {
    asked++;
    return answer;
  }
}

class FakeNotifications implements NotificationService {
  @override
  final opened = ValueNotifier<int>(0);
  final dismissed = <Set<String>>[];
  final shown = <RemoteMessage>[];

  /// Kênh của các lần "nghe thử".
  final previews = <String>[];
  @override
  bool canPreview = true;
  @override
  Future<void> preview(String channel, {required String title}) async =>
      previews.add(channel);

  @override
  Future<void> dismissHandledCards(Set<String> live, DateTime asOf) async =>
      dismissed.add(live);
  @override
  Future<void> handlePush(
    RemoteMessage message, {
    required bool foreground,
  }) async {
    if (foreground) shown.add(message);
  }

  @override
  Future<void> init({
    required void Function(NotificationResponse response) onBackgroundResponse,
  }) async {}
  @override
  Future<String?> handleResponse(NotificationResponse response) async => null;
}

class FakeWidget implements HomeWidgetService {
  /// Mỗi lần vẽ lại: mã các thẻ + số máy.
  final shown = <(List<String>, int)>[];
  final events = <Received>[];
  bool pinnable = true;
  final pinned = <bool>[];

  @override
  Future<void> show(
    List<PendingCard> cards,
    int machines, {
    bool busy = false,
  }) async => shown.add(([for (final card in cards) card.id], machines));
  @override
  Future<void> noteEvent(Received event) async => events.add(event);
  @override
  Future<bool> canPin() async => pinnable;
  @override
  Future<void> pin({bool status = false}) async => pinned.add(status);
  @override
  Future<void> init(Future<void> Function(Uri? uri) onTap) async {}
  @override
  Future<void> sync({Set<String> exclude = const {}}) async {}
  @override
  Future<void> handle(Uri? uri) async {}
}

String _uri(String topicChar, {bool key = true, String project = 'p1'}) =>
    'bowpush://pair?t=bow-${topicChar * 32}&p=$project&n=Mac-$topicChar'
    '${key ? '&k=${'A' * 43}&d=p1-default-rtdb.firebaseio.com' : ''}';

Pairing _pairing(String topicChar, {bool key = true}) =>
    Pairing.parse(_uri(topicChar, key: key))!;

PendingCard _card(Pairing pairing, String id, {bool risky = false}) =>
    PendingCard.fromJson(pairing, '4000', id, {
      'id': id,
      'kind': 'approval',
      'label': 'DUOCT-1',
      'text': 'git push',
      'risky': risky,
      'at': 1,
    })!;

typedef Harness = ({
  ProviderContainer container,
  HomeVm vm,
  FakePush push,
  FakeStore store,
  FakeRemote remote,
  FakeBiometric biometric,
  FakeNotifications notifications,
  FakeWidget widget,
});

/// Dựng ViewModel với các service giả và chờ nó khởi động xong (đọc máy đã ghép, xin quyền, đọc thẻ lần đầu).
Future<Harness> _start({List<Pairing> saved = const [], FakePush? push}) async {
  push ??= FakePush();
  final store = FakeStore(saved);
  final remote = FakeRemote();
  final biometric = FakeBiometric();
  final notifications = FakeNotifications();
  final widget = FakeWidget();
  final container = ProviderContainer(
    overrides: [
      pushServiceProvider.overrideWithValue(push),
      pairingStoreProvider.overrideWithValue(store),
      remoteServiceProvider.overrideWithValue(remote),
      biometricServiceProvider.overrideWithValue(biometric),
      notificationServiceProvider.overrideWithValue(notifications),
      homeWidgetServiceProvider.overrideWithValue(widget),
    ],
  );
  addTearDown(container.dispose);
  // Giữ provider sống suốt bài test (không ai `watch` thì Riverpod tự huỷ ViewModel).
  container.listen(homeVmProvider, (_, _) {});
  final vm = container.read(homeVmProvider.notifier);
  await pumpEventQueue();
  return (
    container: container,
    vm: vm,
    push: push,
    store: store,
    remote: remote,
    biometric: biometric,
    notifications: notifications,
    widget: widget,
  );
}

Future<bool> _never() async => fail('không được hỏi hộp xác nhận');

void main() {
  test('khởi động: nạp máy đã ghép + trạng thái quyền thông báo', () async {
    final a = _pairing('a');
    final h = await _start(saved: [a]);
    final state = h.container.read(homeVmProvider);
    expect(state.pairings, [a]);
    expect(state.notifyDenied, isFalse);
    expect(state.busy, isFalse);
  });

  group('đăng ký nhận thông báo', () {
    test(
      'khởi động: đăng ký LẠI topic của mọi máy đã ghép (cài lại app / khôi phục dữ liệu là mất đăng ký)',
      () async {
        final a = _pairing('a');
        final b = _pairing('b', key: false);
        final h = await _start(saved: [a, b]);
        expect(h.push.subscribed, [a.topic, b.topic]);
        expect(h.container.read(homeVmProvider).notListening, isEmpty);
      },
    );

    test('mã nhận thông báo của máy đổi → đăng ký lại', () async {
      final a = _pairing('a');
      final h = await _start(saved: [a]);
      h.push.subscribed.clear();
      h.push.tokens.add('token-mới');
      await pumpEventQueue();
      expect(h.push.subscribed, [a.topic]);
    });

    test(
      'đăng ký hỏng (mất mạng) → app vẫn chạy, máy đó được đánh dấu "chưa nhận được"; có mạng lại thì hết',
      () async {
        final a = _pairing('a');
        final push = FakePush()..offline = true;
        final h = await _start(saved: [a], push: push);
        final state = h.container.read(homeVmProvider);
        expect(state.pairings, [a]);
        expect(state.notListening, {a.topic});

        push.offline = false;
        push.tokens.add('token-mới');
        await pumpEventQueue();
        expect(h.container.read(homeVmProvider).notListening, isEmpty);
      },
    );
  });

  group('ghép máy', () {
    test(
      'mã rác / mã của dự án Firebase khác → báo, không đăng ký, không lưu',
      () async {
        final h = await _start();
        expect(await h.vm.pair(null), isNull); // người dùng đóng màn quét
        expect(await h.vm.pair('https://example.com'), isNotNull);
        expect(await h.vm.pair(_uri('a', project: 'du-an-khac')), isNotNull);
        expect(h.push.subscribed, isEmpty);
        expect(h.store.saved, isEmpty);
        expect(h.container.read(homeVmProvider).pairings, isEmpty);
      },
    );

    test('mã hợp lệ → đăng ký topic rồi mới lưu', () async {
      final h = await _start();
      expect(await h.vm.pair(_uri('a')), isNotNull);
      expect(h.push.subscribed, ['bow-${'a' * 32}']);
      expect(h.store.saved.single.host, 'Mac-a');
      final state = h.container.read(homeVmProvider);
      expect(state.pairings.single.canApprove, isTrue);
      expect(state.busy, isFalse);
    });

    test(
      'đăng ký topic hỏng → không lưu máy (không thì máy hiện "đã ghép" mà không bao giờ nhận gì)',
      () async {
        final h = await _start();
        h.push.offline = true;
        expect(await h.vm.pair(_uri('a')), isNotNull);
        expect(h.store.saved, isEmpty);
        expect(h.container.read(homeVmProvider).pairings, isEmpty);
        expect(h.container.read(homeVmProvider).busy, isFalse);
      },
    );

    test(
      'quét lại đúng mã cũ → chỉ báo; cùng máy nhưng mã MỚI (thêm khoá duyệt) → thay bản đã lưu, không đăng ký lại',
      () async {
        final h = await _start(saved: [_pairing('a', key: false)]);
        h.push.subscribed
            .clear(); // lần đăng ký lại lúc khởi động — có test riêng
        expect(await h.vm.pair(_uri('a', key: false)), isNotNull);
        expect(
          h.container.read(homeVmProvider).pairings.single.canApprove,
          isFalse,
        );

        expect(await h.vm.pair(_uri('a')), isNotNull);
        expect(h.push.subscribed, isEmpty);
        expect(
          h.container.read(homeVmProvider).pairings.single.canApprove,
          isTrue,
        );
        expect(h.store.saved.single.canApprove, isTrue);
      },
    );
  });

  group('bỏ ghép', () {
    test('bỏ đăng ký được → gỡ máy và lưu', () async {
      final a = _pairing('a');
      final b = _pairing('b');
      final h = await _start(saved: [a, b]);
      expect(await h.vm.unpair(a), isNull);
      expect(h.push.unsubscribed, [a.topic]);
      expect(h.container.read(homeVmProvider).pairings, [b]);
      expect(h.store.saved, [b]);
    });

    test(
      'bỏ đăng ký hỏng → GIỮ máy (gỡ khỏi danh sách mà vẫn nhận thông báo là tệ hơn)',
      () async {
        final a = _pairing('a');
        final h = await _start(saved: [a]);
        h.push.offline = true;
        expect(await h.vm.unpair(a), isNotNull);
        expect(h.container.read(homeVmProvider).pairings, [a]);
      },
    );
  });

  group('thẻ đang chờ', () {
    test(
      'gom thẻ của mọi máy CÓ khoá duyệt; đọc đủ mọi máy thì dọn thông báo của thẻ đã hết',
      () async {
        final a = _pairing('a');
        final b = _pairing('b');
        final noKey = _pairing('c', key: false);
        final h = await _start(saved: [a, b, noKey]);
        h.remote.cards[a.topic] = [_card(a, 'c1')];
        h.remote.cards[b.topic] = [_card(b, 'c2')];
        h.remote.cards[noKey.topic] = [_card(noKey, 'c3')];
        await h.vm.refreshPending();
        expect(
          [for (final c in h.container.read(homeVmProvider).pending) c.id],
          ['c1', 'c2'],
        );
        expect(h.notifications.dismissed.last, {'c1', 'c2'});
        // Widget màn hình chính vẽ lại theo đúng danh sách vừa đọc.
        expect(h.widget.shown.last.$1, ['c1', 'c2']);
        expect(h.widget.shown.last.$2, 3);
      },
    );

    test(
      'một máy mất mạng → vẫn hiện thẻ máy kia, và KHÔNG dọn thông báo (thẻ máy mất mạng có thể còn chờ)',
      () async {
        final a = _pairing('a');
        final b = _pairing('b');
        final h = await _start(saved: [a, b]);
        h.remote.cards[a.topic] = [_card(a, 'c1')];
        h.remote.down.add(b.topic);
        h.notifications.dismissed.clear();
        h.widget.shown.clear();
        await h.vm.refreshPending();
        expect(
          [for (final c in h.container.read(homeVmProvider).pending) c.id],
          ['c1'],
        );
        expect(h.notifications.dismissed, isEmpty);
        expect(h.widget.shown, isEmpty); // widget giữ nguyên thứ đang hiện
      },
    );

    test('bấm vào thông báo → đọc lại thẻ ngay', () async {
      final a = _pairing('a');
      final h = await _start(saved: [a]);
      h.remote.cards[a.topic] = [_card(a, 'c1')];
      h.notifications.opened.value++;
      await pumpEventQueue();
      expect(h.container.read(homeVmProvider).pending.single.id, 'c1');
    });
  });

  group('gửi quyết định', () {
    Future<(Harness, PendingCard)> withCard({bool risky = false}) async {
      final a = _pairing('a');
      final h = await _start(saved: [a]);
      final card = _card(a, 'c1', risky: risky);
      h.remote.cards[a.topic] = [card];
      await h.vm.refreshPending();
      return (h, card);
    }

    test(
      'thẻ thường: gửi luôn, thẻ rời danh sách và không hiện lại dù máy chạy bow chưa kịp gỡ',
      () async {
        final (h, card) = await withCard();
        expect(
          await h.vm.decide(card, {'allow': true}, askRisky: _never),
          isNull,
        );
        expect(h.remote.sent, ['c1 {"allow":true}']);
        expect(h.biometric.asked, 0);
        await pumpEventQueue(); // lượt đọc lại sau khi gửi: database vẫn còn thẻ
        final state = h.container.read(homeVmProvider);
        expect(state.pending, isEmpty);
        expect(state.sending, isEmpty);
      },
    );

    test(
      'thẻ RỦI RO: cho phép phải qua xác thực — không qua thì không gửi gì',
      () async {
        final (h, card) = await withCard(risky: true);
        h.biometric.answer = false;
        expect(
          await h.vm.decide(card, {'allow': true}, askRisky: _never),
          isNull,
        );
        expect(h.remote.sent, isEmpty);
        expect(h.container.read(homeVmProvider).pending.single.id, 'c1');

        h.biometric.answer = true;
        await h.vm.decide(card, {'allow': true}, askRisky: _never);
        expect(h.remote.sent, ['c1 {"allow":true}']);
      },
    );

    test(
      'thẻ rủi ro trên máy KHÔNG xác thực được → hỏi hộp xác nhận; từ chối hộp thì không gửi',
      () async {
        final (h, card) = await withCard(risky: true);
        h.biometric.answer = null;
        var asked = 0;
        await h.vm.decide(
          card,
          {'allow': true},
          askRisky: () async {
            asked++;
            return false;
          },
        );
        expect(asked, 1);
        expect(h.remote.sent, isEmpty);

        await h.vm.decide(card, {'allow': true}, askRisky: () async => true);
        expect(h.remote.sent, ['c1 {"allow":true}']);
      },
    );

    test('TỪ CHỐI thẻ rủi ro không cần xác thực', () async {
      final (h, card) = await withCard(risky: true);
      await h.vm.decide(card, {'allow': false}, askRisky: _never);
      expect(h.biometric.asked, 0);
      expect(h.remote.sent, ['c1 {"allow":false}']);
    });

    test(
      'gửi hỏng → báo lỗi, thẻ vẫn còn để thử lại, nút mở khoá lại',
      () async {
        final (h, card) = await withCard();
        h.remote.rejectReplies = true;
        expect(
          await h.vm.decide(card, {'allow': true}, askRisky: _never),
          isNotNull,
        );
        final state = h.container.read(homeVmProvider);
        expect(state.pending.single.id, 'c1');
        expect(state.sending, isEmpty);
      },
    );
  });

  test(
    'tin tới lúc app đang mở: vào "Vừa nhận" (mới nhất trước) và được dựng thành thông báo',
    () async {
      final h = await _start();
      RemoteMessage message(String title, String kind) => RemoteMessage(
        notification: RemoteNotification(title: title, body: 'DUOCT-1'),
        data: {'kind': kind},
      );
      h.push.messages.add(message('Bow · chờ duyệt', 'approval'));
      h.push.messages.add(message('Bow · đã xong', 'done'));
      h.push.messages.add(
        const RemoteMessage(data: {'kind': 'gone'}),
      ); // tin không có phần hiển thị: bỏ qua
      await pumpEventQueue();
      final recent = h.container.read(homeVmProvider).recent;
      expect(
        [for (final r in recent) (r.kind, r.title)],
        [('done', 'Bow · đã xong'), ('approval', 'Bow · chờ duyệt')],
      );
      expect(h.notifications.shown.length, 2);
      // Widget nhớ "việc gần nhất".
      expect([for (final e in h.widget.events) e.kind], ['approval', 'done']);
    },
  );

  test(
    'widget: đọc được launcher có cho ghim không, và ghim khi người dùng bấm',
    () async {
      final h = await _start();
      expect(h.container.read(homeVmProvider).canPinWidget, isTrue);
      await h.vm.pinWidget();
      await h.vm.pinWidget(status: true);
      expect(h.widget.pinned, [false, true]);
    },
  );

  test('chẩn đoán: báo từng chặng của từng máy và cập nhật dấu chưa đăng ký '
      'được', () async {
    final a = _pairing('a');
    final b = _pairing('b', key: false);
    final h = await _start(saved: [a, b]);
    var checks = await h.vm.diagnose();
    expect(
      [for (final c in checks) (c.subscribed, c.database)],
      [
        (true, true),
        (true, null),
      ], // b chỉ gửi thông báo: không có database để đọc
    );
    expect(h.container.read(homeVmProvider).notListening, isEmpty);

    h.push.offline = true;
    h.remote.down.add(a.topic);
    checks = await h.vm.diagnose();
    expect(
      [for (final c in checks) (c.subscribed, c.database)],
      [(false, false), (false, null)],
    );
    expect(checks.first.error, contains('mất mạng'));
    expect(h.container.read(homeVmProvider).notListening, {a.topic, b.topic});

    // Mạng về: thử lại là hết dấu đỏ.
    h.push.offline = false;
    h.remote.down.clear();
    await h.vm.diagnose();
    expect(h.container.read(homeVmProvider).notListening, isEmpty);
  });
}
