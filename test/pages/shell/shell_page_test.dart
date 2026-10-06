import 'package:bow_notify/src/models/mirror.dart';
import 'package:bow_notify/src/models/pairing.dart';
import 'package:bow_notify/src/models/pending_card.dart';
import 'package:bow_notify/app/app.dart';
import 'package:bow_notify/src/components/bottom_nav.dart';
import 'package:bow_notify/src/constants/links.dart';
import 'package:bow_notify/src/constants/version.dart';
import 'package:bow_notify/src/models/appearance.dart';
import 'package:bow_notify/src/pages/shell/shell_page.dart';
import 'package:bow_notify/src/services/appearance_store.dart';
import 'package:bow_notify/src/services/biometric_service.dart';
import 'package:bow_notify/src/services/home_widget_service.dart';
import 'package:bow_notify/src/services/link_service.dart';
import 'package:bow_notify/src/services/mirror_service.dart';
import 'package:bow_notify/src/services/notification_service.dart';
import 'package:bow_notify/src/services/pairing_store.dart';
import 'package:bow_notify/src/services/prefs_store.dart';
import 'package:bow_notify/src/services/push_service.dart';
import 'package:bow_notify/src/services/remote_service.dart';
import 'package:bow_notify/src/services/update_service.dart';
import 'package:bow_notify/src/themes/bow_theme.dart';
import 'package:bow_notify/src/utils/l10n.dart';
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
import '../settings/update_vm_test.dart' show FakeLinks, FakeUpdates, release;
import '../tabs/tabs_vm_test.dart' show FakeMirror;
import '../tabs/unlock_minutes_test.dart' show FakePrefs;

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

typedef Harness = ({
  FakeRemote remote,
  FakeMirror mirror,
  FakePush push,
  FakeNotifications notifications,
  FakePrefs prefs,
  FakeUpdates updates,
  FakeLinks links,
});

Future<Harness> _pump(
  WidgetTester tester, {
  List<Pairing> saved = const [],
  Map<String, List<PendingCard>> cards = const {},
  Map<String, List<String>> ports = const {},
  FakeAppearanceStore? appearance,
  FakeUpdates? updates,
}) async {
  final remote = FakeRemote()..cards.addAll(cards);
  // Cổng đang có bản sao tab phải khai TRƯỚC khi app mở: ViewModel dò máy ngay lúc khởi động.
  final mirror = FakeMirror()..ports_.addAll(ports);
  final push = FakePush();
  final notifications = FakeNotifications();
  final prefs = FakePrefs();
  // Bản mới nhất GitHub trả phải khai TRƯỚC khi app mở: khung app tự hỏi ngay sau khung hình đầu.
  updates ??= FakeUpdates();
  final links = FakeLinks();
  // Ngôn ngữ ép là biến toàn cục — không để bài này làm đổi chữ của bài sau.
  addTearDown(() => forcedLanguage = null);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pushServiceProvider.overrideWithValue(push),
        pairingStoreProvider.overrideWithValue(FakeStore(saved)),
        remoteServiceProvider.overrideWithValue(remote),
        biometricServiceProvider.overrideWithValue(FakeBiometric()),
        notificationServiceProvider.overrideWithValue(notifications),
        homeWidgetServiceProvider.overrideWithValue(FakeWidget()),
        mirrorServiceProvider.overrideWithValue(mirror),
        appearanceStoreProvider.overrideWithValue(
          appearance ?? FakeAppearanceStore(),
        ),
        prefsStoreProvider.overrideWithValue(prefs),
        updateServiceProvider.overrideWithValue(updates),
        linkServiceProvider.overrideWithValue(links),
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
  return (
    remote: remote,
    mirror: mirror,
    push: push,
    notifications: notifications,
    prefs: prefs,
    updates: updates,
    links: links,
  );
}

/// Bộ token đang áp cho màn hình (đọc từ theme của khung).
Bow _bow(WidgetTester tester) => Bow.of(tester.element(find.byType(ShellPage)));

/// Cuộn danh sách của mục đang mở tới khi thấy [finder]. Chỉ rõ danh sách NGOÀI CÙNG: ghi chú "có gì mới" (chữ
/// chọn + chép được) cũng là một vùng cuộn, để mặc định thì bộ thử không biết cuộn cái nào.
Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

/// Bấm một ô của Cài đặt → Giao diện rồi chờ hoạt ảnh đổi theme xong.
Future<void> _pick(WidgetTester tester, String label) async {
  await _scrollTo(tester, find.text(label));
  // "Thấy" chưa đủ: ô có thể còn nằm dưới thanh điều hướng nổi — kéo nó lên đầu danh sách rồi mới bấm.
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Mở mục Cài đặt (máy thử chạy tiếng Anh).
Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Settings'));
  await tester.pump();
}

/// Hoạt ảnh chuyển màn của Material trên Android dài 800 ms — chờ dư ra, rồi thêm một khung để màn cũ rời hẳn khỏi cây.
Future<void> _settleRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

/// Mở một màn con của Cài đặt (bấm dòng [label]) và chờ hoạt ảnh chuyển màn xong.
Future<void> _openSub(WidgetTester tester, String label) async {
  await _pick(tester, label);
  await _settleRoute(tester);
}

void main() {
  testWidgets('Giao diện → Ngôn ngữ: chọn Tiếng Việt là chữ cả app đổi ngay và '
      'được lưu; chọn English thì đổi lại', (tester) async {
    final store = FakeAppearanceStore();
    await _pump(tester, saved: [_pairing('a')], appearance: store);
    await _openSettings(tester);
    await _pick(tester, 'Tiếng Việt');
    expect(find.text('Cài đặt'), findsOneWidget); // nhãn trên thanh dưới
    expect(find.text('Settings'), findsNothing);
    expect(store.saved.language, AppLanguage.vi);
    // Cả cây dựng lại nhưng vẫn ở mục Cài đặt và vẫn ở đúng chỗ đang cuộn: ô vừa bấm còn trên màn (nhảy về đầu
    // trang thì nhóm Giao diện nằm ngoài vùng được dựng).
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);

    await _pick(tester, 'English');
    expect(find.text('Settings'), findsOneWidget);
    expect(store.saved.language, AppLanguage.en);
  });

  testWidgets('Bảo mật: chọn thời gian giữ mở khoá gõ là lưu lại', (
    tester,
  ) async {
    final h = await _pump(tester, saved: [_pairing('a')]);
    await _openSettings(tester);
    await _pick(tester, '15 min');
    expect(h.prefs.ints, {'unlock_minutes': 15});
    expect(find.text('Always on'), findsOneWidget);
  });

  testWidgets('Âm báo: mỗi loại nghe thử trên đúng kênh của nó; máy không dựng '
      'được thông báo mẫu thì không có nút', (tester) async {
    final h = await _pump(tester, saved: [_pairing('a')]);
    await _openSettings(tester);
    await _openSub(tester, 'Sounds');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Play').at(i));
    }
    expect(h.notifications.previews, ['bow_ask', 'bow_done', 'bow_fail']);

    await tester.tap(find.byTooltip('Back'));
    await _settleRoute(tester);
    h.notifications.canPreview = false; // iPhone
    await _openSub(tester, 'Sounds');
    expect(find.text('Play'), findsNothing);
  });

  testWidgets('Bản mới (iPhone — không cài được APK): mở app là tự hỏi; bấm '
      'Kiểm tra: mất mạng / có bản mới thì nút thành Tải về và mở trang phát '
      'hành', (tester) async {
    final updates = FakeUpdates()..canInstall = false;
    final h = await _pump(tester, saved: [_pairing('a')], updates: updates);
    expect(updates.asked, 1); // tự hỏi lúc mở app
    await _openSettings(tester);
    await _scrollTo(tester, find.text('Check'));
    expect(find.textContaining('this is the latest'), findsOneWidget);
    expect(find.text('Download'), findsNothing);

    updates.latestRelease = null;
    await _pick(tester, 'Check');
    expect(find.textContaining('could not check'), findsOneWidget);

    updates.latestRelease = release('99.0.0');
    await _pick(tester, 'Check');
    expect(find.textContaining('version 99.0.0 is available'), findsOneWidget);
    expect(find.text('What is new in 99.0.0'), findsOneWidget);
    await _pick(tester, 'Download');
    expect(h.links.opened, [releasesPageUrl]);
    expect(updates.downloads, isEmpty);
  });

  testWidgets('Bản mới (Android): mở app là thấy dải báo ở Hôm nay + chấm ở '
      'Cài đặt; bấm Cập nhật là tải rồi mở trình cài đặt, huỷ thì còn nút Cài', (
    tester,
  ) async {
    final updates = FakeUpdates()..latestRelease = release('99.0.0');
    await _pump(tester, saved: [_pairing('a')], updates: updates);
    await tester.pump();
    expect(find.text('Bow Notify 99.0.0'), findsOneWidget);
    expect(find.text('version 99.0.0 is available'), findsOneWidget);
    // Chấm đỏ ở mục Cài đặt của thanh dưới.
    expect(
      find.descendant(of: find.byType(BowBottomNav), matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump();
    expect(updates.downloads, ['99.0.0']);
    expect(updates.installs, ['/tmp/bow-notify-99.0.0.apk']);
    // Trình cài đặt giả trả "huỷ": dải báo còn đó với nút cài lại, không tải lại.
    expect(find.text('Update'), findsNothing);
    await tester.tap(find.text('Install'));
    await tester.pump();
    expect(updates.downloads, ['99.0.0']);
    expect(updates.installs, hasLength(2));

    // Cùng trạng thái đó hiện ở Cài đặt → Về ứng dụng.
    await _openSettings(tester);
    await _scrollTo(tester, find.text('What is new in 99.0.0'));
    expect(find.textContaining('99.0.0 downloaded'), findsOneWidget);
  });

  testWidgets('Bản mới: gạt dải báo ở Hôm nay ("Để sau") thì dải biến mất, '
      'chấm ở Cài đặt và nút Cập nhật ở đó vẫn còn', (tester) async {
    final updates = FakeUpdates()..latestRelease = release('99.0.0');
    await _pump(tester, saved: [_pairing('a')], updates: updates);
    await tester.pump();
    await tester.tap(find.byTooltip('Later'));
    await tester.pump();
    expect(find.text('Bow Notify 99.0.0'), findsNothing);
    expect(
      find.descendant(of: find.byType(BowBottomNav), matching: find.text('1')),
      findsOneWidget,
    );
    await _openSettings(tester);
    await _scrollTo(tester, find.text('Update'));
    expect(find.textContaining('version 99.0.0 is available'), findsOneWidget);
  });

  testWidgets('Bản mới: chưa ghép máy nào cũng thấy dải báo; cài hỏng vì '
      'khác khoá thì nói rõ và mời tải bằng trình duyệt', (tester) async {
    final updates = FakeUpdates()
      ..latestRelease = release('99.0.0')
      ..installResult = InstallResult.conflict;
    final h = await _pump(tester, updates: updates);
    await tester.pump();
    expect(find.text('Bow Notify 99.0.0'), findsOneWidget);
    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('signed with a different key'), findsOneWidget);

    await _openSettings(tester);
    await _pick(tester, 'Download in the browser ›');
    expect(h.links.opened, [latestApkUrl]);
  });

  testWidgets('Bản mới: chọn "chỉ khi bấm" là lưu lại; không có bản mới thì '
      'không có dải báo, không có chấm', (tester) async {
    final h = await _pump(tester, saved: [_pairing('a')]);
    await tester.pump();
    expect(find.textContaining('Bow Notify $appVersion'), findsNothing);
    expect(
      find.descendant(of: find.byType(BowBottomNav), matching: find.text('1')),
      findsNothing,
    );
    await _openSettings(tester);
    await _pick(tester, 'Only when I press');
    expect(h.prefs.ints, {'update_auto': 0});
  });

  testWidgets('Chẩn đoán: mở ra là thử từng chặng của từng máy; chặng hỏng '
      'được chỉ rõ', (tester) async {
    final a = _pairing('a');
    final h = await _pump(tester, saved: [a]);
    await _openSettings(tester);
    await _openSub(tester, 'Diagnostics');
    expect(find.text('Notification subscription: OK.'), findsOneWidget);
    expect(find.text('Approval cards: readable.'), findsOneWidget);

    h.push.offline = true;
    h.remote.down.add(a.topic);
    await tester.tap(find.text('Check again'));
    await tester.pump();
    await tester.pump();
    expect(
      find.textContaining('Notification subscription: failed'),
      findsOneWidget,
    );
    expect(find.textContaining('Approval cards: cannot read'), findsOneWidget);

    await tester.ensureVisible(find.text('Test notification here'));
    await tester.pump();
    await tester.tap(find.text('Test notification here'));
    expect(h.notifications.previews, ['bow_ask']);
  });

  testWidgets('Hướng dẫn: mở được, dòng tài liệu mở link GitHub', (
    tester,
  ) async {
    final h = await _pump(tester, saved: [_pairing('a')]);
    await _openSettings(tester);
    await _openSub(tester, 'Guide');
    expect(find.text('Pair a machine'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Full documentation'), 300);
    await tester.ensureVisible(find.text('Full documentation'));
    await tester.pump();
    await tester.tap(find.text('Full documentation'));
    expect(h.links.opened, [readmeUrl]);
  });

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
    expect(store.saved, (
      style: BowStyle.glass,
      mode: GlassMode.dark,
      language: AppLanguage.system,
    ));
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
