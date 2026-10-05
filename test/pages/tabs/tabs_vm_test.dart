import 'dart:async';

import 'package:bow_notify/src/models/mirror.dart';
import 'package:bow_notify/src/models/pairing.dart';
import 'package:bow_notify/src/pages/tabs/new_task_vm.dart';
import 'package:bow_notify/src/pages/tabs/tab_vm.dart';
import 'package:bow_notify/src/pages/tabs/tabs_vm.dart';
import 'package:bow_notify/src/pages/tabs/typing_gate.dart';
import 'package:bow_notify/src/services/biometric_service.dart';
import 'package:bow_notify/src/services/mirror_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Hai ViewModel của "tab trên máy", chạy với service GIẢ — không mạng, không database.

class FakeMirror implements MirrorService {
  /// Cổng đang có bản sao, theo topic của máy.
  final ports_ = <String, List<String>>{};
  final offline = <String>{};
  final tabs = <String, StreamController<MachineTabs?>>{};
  final chats = <String, StreamController<List<MirrorItem>>>{};

  /// Các câu đã gửi vào tab (`cổng|tab|câu`) và kết quả máy sẽ báo lại.
  final said = <String>[];
  SayResult answer = (ok: true, reason: '', tabId: '');
  Completer<void>? hold;

  /// Các việc mới đã giao (`cổng|dự án|đề bài|tự duyệt|autopilot`).
  final tasks = <String>[];

  @override
  Future<SayResult> newTask(
    Pairing pairing,
    String port, {
    required String projectId,
    required String text,
    required bool autoApprove,
    required bool autopilot,
  }) async {
    tasks.add('$port|$projectId|$text|$autoApprove|$autopilot');
    await hold?.future;
    return answer;
  }

  @override
  Future<SayResult> say(
    Pairing pairing,
    String port,
    String tabId,
    String text,
  ) async {
    said.add('$port|$tabId|$text');
    await hold?.future;
    return answer;
  }

  /// Số luồng đang có người nghe.
  int get listening =>
      tabs.values.where((c) => c.hasListener).length +
      chats.values.where((c) => c.hasListener).length;

  @override
  Future<List<String>> ports(Pairing pairing) async {
    if (offline.contains(pairing.topic)) throw Exception('mất mạng');
    return ports_[pairing.topic] ?? const [];
  }

  @override
  Stream<MachineTabs?> watchTabs(Pairing pairing, String port) =>
      (tabs['${pairing.topic}|$port'] = StreamController<MachineTabs?>())
          .stream;

  @override
  Stream<List<MirrorItem>> watchChat(
    Pairing pairing,
    String port,
    String tabId,
  ) =>
      (chats['${pairing.topic}|$port|$tabId'] =
              StreamController<List<MirrorItem>>())
          .stream;
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

Pairing _pairing(String c) => Pairing.parse(
  'bowpush://pair?t=bow-${c * 32}&p=p1&n=Mac-$c&k=${'A' * 43}&d=p1-default-rtdb.firebaseio.com',
)!;

MachineTabs _tabs(Pairing pairing, String port, List<String> ids) =>
    MachineTabs(
      pairing: pairing,
      port: port,
      at: DateTime.now(),
      active: ids.firstOrNull ?? '',
      tabs: [
        for (final id in ids)
          MirrorTab(
            id: id,
            title: 'tab $id',
            project: 'p',
            running: false,
            pending: 0,
          ),
      ],
    );

({ProviderContainer container, FakeMirror mirror, FakeBiometric biometric})
_setup(List<Pairing> pairings) {
  final mirror = FakeMirror();
  final biometric = FakeBiometric();
  final container = ProviderContainer(
    overrides: [
      mirrorPairingsProvider.overrideWithValue(pairings),
      mirrorServiceProvider.overrideWithValue(mirror),
      biometricServiceProvider.overrideWithValue(biometric),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, mirror: mirror, biometric: biometric);
}

Future<bool> _never() async => fail('không được hỏi hộp xác nhận');

void main() {
  test(
    'dò cổng của từng máy rồi nghe thanh tab; có dữ liệu thì hiện, bản sao bị gỡ (null) thì bỏ',
    () async {
      final a = _pairing('a');
      final h = _setup([a]);
      h.mirror.ports_[a.topic] = ['4000', '4005'];
      h.container.listen(tabsVmProvider, (_, _) {});
      await pumpEventQueue();
      expect(h.mirror.tabs.keys, ['${a.topic}|4000', '${a.topic}|4005']);
      expect(
        h.container.read(tabsVmProvider),
        isEmpty,
      ); // chưa có dữ liệu nào tới

      h.mirror.tabs['${a.topic}|4000']!.add(_tabs(a, '4000', ['t1', 't2']));
      h.mirror.tabs['${a.topic}|4005']!.add(_tabs(a, '4005', ['x']));
      await pumpEventQueue();
      expect(
        [
          for (final m in h.container.read(tabsVmProvider))
            (m.port, m.tabs.length),
        ],
        [('4000', 2), ('4005', 1)],
      );

      h.mirror.tabs['${a.topic}|4005']!.add(
        null,
      ); // máy tắt "xem tab trên điện thoại" ở cổng đó
      await pumpEventQueue();
      expect(
        [for (final m in h.container.read(tabsVmProvider)) m.port],
        ['4000'],
      );
    },
  );

  test(
    'app khuất → đóng mọi luồng nhưng GIỮ dữ liệu đang có; trở lại thì nghe tiếp',
    () async {
      final a = _pairing('a');
      final h = _setup([a]);
      h.mirror.ports_[a.topic] = ['4000'];
      h.container.listen(tabsVmProvider, (_, _) {});
      await pumpEventQueue();
      h.mirror.tabs['${a.topic}|4000']!.add(_tabs(a, '4000', ['t1']));
      await pumpEventQueue();
      expect(h.mirror.listening, 1);

      h.container.read(tabsVmProvider.notifier).paused();
      await pumpEventQueue();
      expect(h.mirror.listening, 0);
      expect(h.container.read(tabsVmProvider).single.tabs.single.id, 't1');

      h.container.read(tabsVmProvider.notifier).resumed();
      await pumpEventQueue();
      expect(h.mirror.listening, 1);
    },
  );

  test('một máy mất mạng lúc dò cổng không làm hỏng máy kia', () async {
    final a = _pairing('a');
    final b = _pairing('b');
    final h = _setup([a, b]);
    h.mirror.offline.add(a.topic);
    h.mirror.ports_[b.topic] = ['4000'];
    h.container.listen(tabsVmProvider, (_, _) {});
    await pumpEventQueue();
    expect(h.mirror.tabs.keys, ['${b.topic}|4000']);
  });

  test(
    'màn hội thoại: nghe đúng tab, có dữ liệu thì hiện; rời màn là đóng luồng',
    () async {
      final a = _pairing('a');
      final h = _setup([a]);
      final ref = (topic: a.topic, port: '4000', tabId: 't1');
      final sub = h.container.listen(tabVmProvider(ref), (_, _) {});
      await pumpEventQueue();
      expect(h.container.read(tabVmProvider(ref)).loaded, isFalse);

      h.mirror.chats['${a.topic}|4000|t1']!.add([
        const MirrorItem(id: 'i1', kind: 'user', text: 'làm đi', order: 0),
        const MirrorItem(id: 'i2', kind: 'agent', text: 'xong', order: 1),
      ]);
      await pumpEventQueue();
      final state = h.container.read(tabVmProvider(ref));
      expect(state.loaded, isTrue);
      expect([for (final item in state.items) item.id], ['i1', 'i2']);

      sub.close(); // rời màn
      await pumpEventQueue();
      expect(h.mirror.listening, 0);
    },
  );

  test(
    'máy đã bị bỏ ghép → màn hội thoại không nghe gì (không có khoá để giải mã)',
    () async {
      final h = _setup([]);
      final ref = (topic: 'bow-${'z' * 32}', port: '4000', tabId: 't1');
      h.container.listen(tabVmProvider(ref), (_, _) {});
      await pumpEventQueue();
      expect(h.mirror.chats, isEmpty);
    },
  );

  group('gõ vào tab', () {
    ({
      ProviderContainer container,
      FakeMirror mirror,
      FakeBiometric biometric,
      TabVm vm,
      TabRef ref,
    })
    open() {
      final a = _pairing('a');
      final h = _setup([a]);
      final ref = (topic: a.topic, port: '4000', tabId: 't1');
      h.container.listen(tabVmProvider(ref), (_, _) {});
      return (
        container: h.container,
        mirror: h.mirror,
        biometric: h.biometric,
        vm: h.container.read(tabVmProvider(ref).notifier),
        ref: ref,
      );
    }

    test(
      'lần đầu phải qua vân tay; trong 5 phút sau đó gửi tiếp KHÔNG hỏi lại; app ra nền (khoá) thì hỏi lại',
      () async {
        final h = open();
        expect(await h.vm.send('  chạy test  ', askFallback: _never), isNull);
        expect(h.mirror.said, [
          '4000|t1|chạy test',
        ]); // gọt khoảng trắng, đúng tab
        expect(h.biometric.asked, 1);

        expect(await h.vm.send('tiếp', askFallback: _never), isNull);
        expect(h.biometric.asked, 1);

        h.container.read(typingGateProvider.notifier).lock();
        await h.vm.send('push', askFallback: _never);
        expect(h.biometric.asked, 2);
        expect(h.mirror.said.length, 3);
      },
    );

    test(
      'vân tay không qua → KHÔNG gửi gì, không báo lỗi (người dùng tự huỷ)',
      () async {
        final h = open();
        h.biometric.answer = false;
        expect(await h.vm.send('rm -rf', askFallback: _never), '');
        expect(h.mirror.said, isEmpty);
        expect(h.container.read(typingGateProvider), isNull);
      },
    );

    test(
      'máy không xác thực được → hỏi hộp xác nhận; từ chối thì không gửi, đồng ý thì gửi và mở khoá',
      () async {
        final h = open();
        h.biometric.answer = null;
        expect(await h.vm.send('tiếp', askFallback: () async => false), '');
        expect(h.mirror.said, isEmpty);
        expect(await h.vm.send('tiếp', askFallback: () async => true), isNull);
        expect(h.mirror.said.length, 1);
        expect(h.container.read(typingGateProvider), isNotNull);
      },
    );

    test(
      'máy báo không tới (trang web không mở) → có câu báo lỗi, ô nhập được mở lại',
      () async {
        final h = open();
        h.mirror.answer = (ok: false, reason: 'no-web', tabId: '');
        final error = await h.vm.send('tiếp', askFallback: _never);
        expect(error, sayFailure('no-web'));
        expect(error, isNotEmpty);
        expect(h.container.read(tabVmProvider(h.ref)).sending, isNull);
      },
    );

    test(
      'đang gửi dở thì khoá ô nhập (không gửi chồng câu thứ hai); câu rỗng thì bỏ qua',
      () async {
        final h = open();
        h.mirror.hold = Completer<void>();
        final first = h.vm.send('một', askFallback: _never);
        await pumpEventQueue();
        expect(h.container.read(tabVmProvider(h.ref)).sending, 'một');
        expect(await h.vm.send('hai', askFallback: _never), '');
        h.mirror.hold!.complete();
        expect(await first, isNull);
        expect(h.mirror.said, ['4000|t1|một']);
        expect(await h.vm.send('   ', askFallback: _never), '');
      },
    );

    test('mỗi lý do thất bại có một câu riêng, lý do lạ thì có câu chung', () {
      final known = [
        'no-web',
        'no-answer',
        'tab-closed',
        'attachments',
        'stale',
        'denied',
        'timeout',
        'no-project',
      ];
      expect({for (final r in known) sayFailure(r)}.length, known.length);
      expect(sayFailure('gì-đó-mới'), sayFailure('refused'));
    });
  });

  group('giao việc mới', () {
    final a = _pairing('a');
    const machine = (
      topic: 'bow-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      port: '4000',
    );

    ({
      ProviderContainer container,
      FakeMirror mirror,
      FakeBiometric biometric,
      NewTaskVm vm,
    })
    open() {
      final h = _setup([a]);
      h.container.listen(newTaskVmProvider(machine), (_, _) {});
      return (
        container: h.container,
        mirror: h.mirror,
        biometric: h.biometric,
        vm: h.container.read(newTaskVmProvider(machine).notifier),
      );
    }

    test(
      'LUÔN hỏi vân tay — kể cả khi phiên gõ 5 phút đang mở; gửi đúng dự án + hai công tắc; trả mã tab vừa mở',
      () async {
        final h = open();
        expect(a.topic, machine.topic);
        h.mirror.answer = (ok: true, reason: '', tabId: 'tab-moi');
        h.container.read(typingGateProvider.notifier).unlockNow();

        final first = await h.vm.send(
          '  sửa lỗi đăng nhập  ',
          projectId: 'p1',
          askFallback: _never,
        );
        expect(first, (tabId: 'tab-moi', error: ''));
        expect(h.biometric.asked, 1);
        expect(h.mirror.tasks, ['4000|p1|sửa lỗi đăng nhập|false|false']);

        h.vm.setAutoApprove(true);
        h.vm.setAutopilot(true);
        await h.vm.send('DULB-12', projectId: 'p2', askFallback: _never);
        expect(h.biometric.asked, 2); // việc thứ hai vẫn hỏi lại
        expect(h.mirror.tasks.last, '4000|p2|DULB-12|true|true');
      },
    );

    test(
      'hai công tắc mặc định TẮT; giao xong thì phiên gõ được mở (câu kế trong tab mới khỏi hỏi lại)',
      () async {
        final h = open();
        final state = h.container.read(newTaskVmProvider(machine));
        expect((state.autoApprove, state.autopilot), (false, false));
        expect(h.container.read(typingGateProvider), isNull);
        await h.vm.send('việc', projectId: '', askFallback: _never);
        expect(h.container.read(typingGateProvider), isNotNull);
      },
    );

    test(
      'vân tay không qua → KHÔNG gửi gì, không báo lỗi; máy không xác thực được thì hỏi hộp xác nhận',
      () async {
        final h = open();
        h.biometric.answer = false;
        expect(await h.vm.send('việc', projectId: 'p1', askFallback: _never), (
          tabId: null,
          error: '',
        ));
        h.biometric.answer = null;
        expect(
          await h.vm.send(
            'việc',
            projectId: 'p1',
            askFallback: () async => false,
          ),
          (tabId: null, error: ''),
        );
        expect(h.mirror.tasks, isEmpty);
        expect(h.container.read(typingGateProvider), isNull);
        final ok = await h.vm.send(
          'việc',
          projectId: 'p1',
          askFallback: () async => true,
        );
        expect(ok.error, '');
        expect(h.mirror.tasks.length, 1);
      },
    );

    test(
      'máy từ chối (dự án đã gỡ / trang web không mở) → có câu báo lỗi, không mở phiên gõ, gửi lại được',
      () async {
        final h = open();
        h.mirror.answer = (ok: false, reason: 'no-project', tabId: '');
        final result = await h.vm.send(
          'việc',
          projectId: 'cũ',
          askFallback: _never,
        );
        expect(result, (tabId: null, error: sayFailure('no-project')));
        expect(h.container.read(typingGateProvider), isNull);
        expect(h.container.read(newTaskVmProvider(machine)).sending, isFalse);
      },
    );

    test(
      'đang gửi dở thì không gửi chồng việc thứ hai; đề bài rỗng thì bỏ qua',
      () async {
        final h = open();
        h.mirror.hold = Completer<void>();
        final first = h.vm.send('một', projectId: 'p1', askFallback: _never);
        await pumpEventQueue();
        expect(h.container.read(newTaskVmProvider(machine)).sending, isTrue);
        expect(await h.vm.send('hai', projectId: 'p1', askFallback: _never), (
          tabId: null,
          error: '',
        ));
        h.mirror.hold!.complete();
        await first;
        expect(h.mirror.tasks.length, 1);
        expect(await h.vm.send('   ', projectId: 'p1', askFallback: _never), (
          tabId: null,
          error: '',
        ));
        expect(h.biometric.asked, 1);
      },
    );

    test(
      'dự án chọn sẵn = dự án của tab đang mở trên máy; tab đó không gắn dự án thì lấy dự án đầu; máy không có dự án thì rỗng',
      () {
        MachineTabs tabs(String activeProject, List<MirrorProject> projects) =>
            MachineTabs(
              pairing: a,
              port: '4000',
              at: DateTime.now(),
              active: 't2',
              projects: projects,
              tabs: [
                const MirrorTab(
                  id: 't1',
                  title: '',
                  project: 'A',
                  projectId: 'pa',
                  running: false,
                  pending: 0,
                ),
                MirrorTab(
                  id: 't2',
                  title: '',
                  project: '',
                  projectId: activeProject,
                  running: false,
                  pending: 0,
                ),
              ],
            );
        const projects = [(id: 'pa', name: 'A'), (id: 'pb', name: 'B')];
        expect(defaultProject(tabs('pb', projects)), 'pb');
        expect(defaultProject(tabs('', projects)), 'pa');
        expect(defaultProject(tabs('đã-gỡ', projects)), 'pa');
        expect(defaultProject(tabs('pb', const [])), '');
      },
    );
  });
}
