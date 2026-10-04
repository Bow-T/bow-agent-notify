import 'dart:async';

import 'package:bow_notify/src/models/mirror.dart';
import 'package:bow_notify/src/models/pairing.dart';
import 'package:bow_notify/src/pages/tabs/tab_vm.dart';
import 'package:bow_notify/src/pages/tabs/tabs_vm.dart';
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

({ProviderContainer container, FakeMirror mirror}) _setup(
  List<Pairing> pairings,
) {
  final mirror = FakeMirror();
  final container = ProviderContainer(
    overrides: [
      mirrorPairingsProvider.overrideWithValue(pairings),
      mirrorServiceProvider.overrideWithValue(mirror),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, mirror: mirror);
}

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
}
