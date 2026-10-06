import 'package:bow_notify/src/models/mirror.dart';
import 'package:bow_notify/src/models/pairing.dart';
import 'package:bow_notify/src/models/pending_card.dart';
import 'package:bow_notify/app/app.dart';
import 'package:bow_notify/src/models/appearance.dart';
import 'package:bow_notify/src/pages/shell/shell_page.dart';
import 'package:bow_notify/src/services/appearance_store.dart';
import 'package:bow_notify/src/services/biometric_service.dart';
import 'package:bow_notify/src/services/home_widget_service.dart';
import 'package:bow_notify/src/services/mirror_service.dart';
import 'package:bow_notify/src/services/notification_service.dart';
import 'package:bow_notify/src/services/pairing_store.dart';
import 'package:bow_notify/src/services/push_service.dart';
import 'package:bow_notify/src/services/remote_service.dart';
import 'package:bow_notify/src/themes/bow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_vm_test.dart'
    show
        FakeBiometric,
        FakeNotifications,
        FakePush,
        FakeRemote,
        FakeStore,
        FakeWidget;
import '../settings/appearance_vm_test.dart' show FakeAppearanceStore;
import '../tabs/tabs_vm_test.dart' show FakeMirror;

// Khung app (thanh trên + bốn mục ở thanh dưới) chạy với service GIẢ. Máy thử chạy tiếng Anh nên nhãn là tiếng Anh.

Pairing _pairing(String c) => Pairing.parse(
  'bowpush://pair?t=bow-${c * 32}&p=p1&n=Mac-$c&k=${'A' * 43}&d=p1-default-rtdb.firebaseio.com',
)!;

PendingCard _card(Pairing pairing, String id) =>
    PendingCard.fromJson(pairing, '4000', id, {
      'id': id,
      'kind': 'approval',
      'label': 'DUOCT-1',
      'text': 'git push',
      'risky': false,
      'at': 1,
    })!;

typedef Harness = ({FakeRemote remote, FakeMirror mirror});

Future<Harness> _pump(
  WidgetTester tester, {
  List<Pairing> saved = const [],
  Map<String, List<PendingCard>> cards = const {},
  Map<String, List<String>> ports = const {},
  FakeAppearanceStore? appearance,
}) async {
  final remote = FakeRemote()..cards.addAll(cards);
  // Cổng đang có bản sao tab phải khai TRƯỚC khi app mở: ViewModel dò máy ngay lúc khởi động.
  final mirror = FakeMirror()..ports_.addAll(ports);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pushServiceProvider.overrideWithValue(FakePush()),
        pairingStoreProvider.overrideWithValue(FakeStore(saved)),
        remoteServiceProvider.overrideWithValue(remote),
        biometricServiceProvider.overrideWithValue(FakeBiometric()),
        notificationServiceProvider.overrideWithValue(FakeNotifications()),
        homeWidgetServiceProvider.overrideWithValue(FakeWidget()),
        mirrorServiceProvider.overrideWithValue(mirror),
        appearanceStoreProvider.overrideWithValue(
          appearance ?? FakeAppearanceStore(),
        ),
      ],
      // Có kho giao diện ⇒ dựng cả app (theme đi theo lựa chọn); không thì chỉ khung, theme kính sáng.
      child: appearance != null
          ? const BowNotifyApp()
          : MaterialApp(theme: bowTheme(Bow.light), home: const ShellPage()),
    ),
  );
  // ViewModel khởi động (đọc máy đã ghép, xin quyền, đọc thẻ lần đầu) rồi màn hình vẽ lại.
  await tester.pump();
  await tester.pump();
  // Gỡ cây widget cuối bài: ViewModel huỷ thì các nhịp hỏi máy của nó mới dừng.
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  return (remote: remote, mirror: mirror);
}

/// Bộ token đang áp cho màn hình (đọc từ theme của khung).
Bow _bow(WidgetTester tester) => Bow.of(tester.element(find.byType(ShellPage)));

/// Bấm một ô của Cài đặt → Giao diện rồi chờ hoạt ảnh đổi theme xong.
Future<void> _pick(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 200);
  // "Thấy" chưa đủ: ô có thể còn nằm dưới thanh điều hướng nổi — kéo nó lên đầu danh sách rồi mới bấm.
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Cài đặt → Giao diện: đổi sang brutal là cả app đổi theme và lựa '
      'chọn được lưu; chế độ màu chỉ có ở kính', (tester) async {
    final store = FakeAppearanceStore();
    await _pump(tester, saved: [_pairing('a')], appearance: store);
    expect(_bow(tester).style, BowStyle.glass);
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Colour mode'), 200);

    await _pick(tester, 'Brutal');
    expect(_bow(tester).style, BowStyle.brutal);
    expect(store.saved.style, BowStyle.brutal);
    expect(find.text('Colour mode'), findsNothing);

    await _pick(tester, 'Glass');
    await _pick(tester, 'Dark');
    expect(store.saved, (style: BowStyle.glass, mode: GlassMode.dark));
    expect(_bow(tester).isDark, isTrue);
  });

  testWidgets('brutal: bốn mục và thẻ chờ duyệt dựng được, cặp nút duyệt viết '
      'hoa', (tester) async {
    final a = _pairing('a');
    await _pump(
      tester,
      saved: [a],
      cards: {
        a.topic: [_card(a, 'c1')],
      },
      appearance: FakeAppearanceStore(),
    );
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await _pick(tester, 'Brutal');
    for (final tab in ['Activity', 'Tabs', 'Today']) {
      await tester.tap(find.text(tab));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'mục $tab');
    }
    expect(find.text('ALLOW'), findsOneWidget);
    expect(find.text('DENY'), findsOneWidget);
  });

  testWidgets('chưa ghép máy nào: Hôm nay là màn hướng dẫn ghép', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Nothing paired yet'), findsOneWidget);
    expect(find.text('Three steps'.toUpperCase()), findsOneWidget);
    expect(find.byTooltip('Scan pairing code'), findsOneWidget);
  });

  testWidgets('đã ghép, có thẻ chờ: thẻ nằm ở Hôm nay và số thẻ hiện trên '
      'thanh dưới', (tester) async {
    final a = _pairing('a');
    await _pump(
      tester,
      saved: [a],
      cards: {
        a.topic: [_card(a, 'c1'), _card(a, 'c2')],
      },
    );
    expect(find.text('Waiting for you · 2'.toUpperCase()), findsOneWidget);
    // Số trên mục Hôm nay của thanh dưới.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Nothing paired yet'), findsNothing);
  });

  testWidgets('đã ghép, không có thẻ: ghi rõ là hết việc', (tester) async {
    await _pump(tester, saved: [_pairing('a')]);
    expect(find.text('Nothing is waiting for you'), findsOneWidget);
    expect(find.textContaining('Listening to 1 machine'), findsOneWidget);
  });

  testWidgets('bấm thanh dưới chuyển mục; Cài đặt có máy đã ghép và phiên '
      'bản', (tester) async {
    await _pump(tester, saved: [_pairing('a')]);
    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('Paired machines'.toUpperCase()), findsOneWidget);
    expect(find.text('Mac-a'), findsOneWidget);
    expect(find.text('Pair another machine'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Version '), 200);
    expect(find.textContaining('Version '), findsOneWidget);

    await tester.tap(find.text('Activity'));
    await tester.pump();
    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets('mục Tab: hiện tab của máy, lọc theo trạng thái', (tester) async {
    final a = _pairing('a');
    final h = await _pump(
      tester,
      saved: [a],
      ports: {
        a.topic: ['4000'],
      },
    );
    await tester.tap(find.text('Tabs'));
    await tester.pump();
    expect(find.text('No tabs yet'), findsOneWidget);

    // Bản sao thanh tab tới: một tab đang chạy, một tab đứng yên.
    h.mirror.tabs['${a.topic}|4000']!.add(
      MachineTabs(
        pairing: a,
        port: '4000',
        at: DateTime.now(),
        active: 't1',
        tabs: const [
          MirrorTab(
            id: 't1',
            title: 'Fix login',
            project: 'p',
            running: true,
            pending: 0,
          ),
          MirrorTab(
            id: 't2',
            title: 'Write tests',
            project: 'p',
            running: false,
            pending: 0,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Fix login'), findsOneWidget);
    expect(find.text('Write tests'), findsOneWidget);
    await tester.tap(find.text('Running · 1'));
    await tester.pump();
    expect(find.text('Fix login'), findsOneWidget);
    expect(find.text('Write tests'), findsNothing);
  });
}
