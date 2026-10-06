import 'dart:async';

import 'package:bow_notify/src/constants/links.dart';
import 'package:bow_notify/src/constants/version.dart';
import 'package:bow_notify/src/models/app_release.dart';
import 'package:bow_notify/src/pages/settings/update_vm.dart';
import 'package:bow_notify/src/services/link_service.dart';
import 'package:bow_notify/src/services/prefs_store.dart';
import 'package:bow_notify/src/services/update_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tabs/unlock_minutes_test.dart' show FakePrefs;

// Cập nhật app (Cài đặt → Về ứng dụng + dải báo ở Hôm nay), chạy với GitHub / trình cài đặt GIẢ.

/// Một bản phát hành có kèm APK.
AppRelease release(String version) =>
    AppRelease(tag: 'v$version', notes: 'Có gì mới', apkSize: 1000);

class FakeUpdates implements UpdateService {
  /// Bản mới nhất GitHub sẽ trả; `null` = mất mạng.
  AppRelease? latestRelease = release(appVersion);

  /// Khác `null` = lời hỏi GitHub treo tới khi hoàn tất cái này (mạng chậm).
  Completer<void>? latestGate;

  /// `false` = iPhone: không cài được APK.
  @override
  bool canInstall = true;

  var asked = 0;
  var downloadFails = false;

  /// Khác `null` = lần tải dừng ở 40% tới khi hoàn tất cái này.
  Completer<void>? downloadGate;
  final downloads = <String>[];
  final installs = <String>[];

  /// Trình cài đặt trả lời gì; `null` = chưa trả lời (hộp của máy còn mở).
  InstallResult? installResult = InstallResult.cancelled;
  String? installMessage;

  @override
  Future<AppRelease> latest() async {
    asked++;
    await latestGate?.future;
    return latestRelease ?? (throw Exception('mất mạng'));
  }

  @override
  Future<String> download(
    AppRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloads.add(release.version);
    onProgress?.call(400, 1000);
    await downloadGate?.future;
    if (downloadFails) throw Exception('mạng đứt');
    onProgress?.call(1000, 1000);
    return '/tmp/bow-notify-${release.version}.apk';
  }

  @override
  Future<({InstallResult result, String? message})> install(String path) {
    installs.add(path);
    final result = installResult;
    return result == null
        ? Completer<({InstallResult result, String? message})>().future
        : Future.value((result: result, message: installMessage));
  }
}

class FakeLinks implements LinkService {
  final opened = <String>[];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}

typedef _Harness = ({
  ProviderContainer container,
  FakeUpdates updates,
  FakePrefs prefs,
  FakeLinks links,
  UpdateVm vm,
});

_Harness _setup({FakePrefs? prefs}) {
  final updates = FakeUpdates();
  final store = prefs ?? FakePrefs();
  final links = FakeLinks();
  final container = ProviderContainer(
    overrides: [
      updateServiceProvider.overrideWithValue(updates),
      prefsStoreProvider.overrideWithValue(store),
      linkServiceProvider.overrideWithValue(links),
    ],
  );
  addTearDown(container.dispose);
  return (
    container: container,
    updates: updates,
    prefs: store,
    links: links,
    vm: container.read(updateVmProvider.notifier),
  );
}

void main() {
  UpdateState state(_Harness h) => h.container.read(updateVmProvider);

  test(
    'tự kiểm tra: mở app hỏi một lần, trở lại ngay sau đó không hỏi nữa',
    () async {
      final h = _setup();
      await h.vm.autoCheck();
      await h.vm.autoCheck();
      expect(h.updates.asked, 1);
      expect(state(h).phase, UpdatePhase.current);
      expect(state(h).offer, isFalse);
    },
  );

  test('mở app lúc mất mạng: lần hỏi hỏng không tính — trở lại app là hỏi lại; '
      'hỏi được rồi mới thôi', () async {
    final h = _setup()..updates.latestRelease = null;
    await h.vm.autoCheck();
    await h.vm.autoCheck();
    expect(h.updates.asked, 2);
    expect(state(h).problem, isNull);

    h.updates.latestRelease = release('99.0.0');
    await h.vm.autoCheck();
    expect(h.updates.asked, 3);
    expect(state(h).offer, isTrue);
    await h.vm.autoCheck();
    expect(h.updates.asked, 3);
  });

  test('tắt tự kiểm tra: không hỏi, lựa chọn được lưu và nạp lại; bật lại là '
      'hỏi ngay', () async {
    final h = _setup();
    h.vm.setAuto(false);
    await pumpEventQueue();
    expect(h.prefs.ints, {'update_auto': 0});
    await h.vm.autoCheck();
    expect(h.updates.asked, 0);

    final again = _setup(prefs: h.prefs);
    expect(state(again).auto, isTrue); // mặc định, trước khi nạp
    await again.vm.load();
    expect(state(again).auto, isFalse);
    await again.vm.autoCheck();
    expect(again.updates.asked, 0);

    again.vm.setAuto(true);
    await pumpEventQueue();
    expect(again.prefs.ints, {'update_auto': 1});
    expect(again.updates.asked, 1);
  });

  test('kho lưu hỏng: vẫn tự kiểm tra (mặc định bật)', () async {
    final h = _setup()..prefs.broken = true;
    await h.vm.load();
    expect(state(h).auto, isTrue);
  });

  test('mất mạng: lần hỏi ngầm im lặng, lần bấm tay mới báo lỗi; hỏi lại được '
      'thì lỗi biến mất', () async {
    final h = _setup()..updates.latestRelease = null;
    await h.vm.autoCheck();
    expect(state(h).phase, UpdatePhase.idle);
    expect(state(h).problem, isNull);

    await h.vm.check();
    expect(state(h).phase, UpdatePhase.idle);
    expect(state(h).problem, UpdateProblem.check);

    h.updates.latestRelease = release('99.0.0');
    await h.vm.check();
    expect(state(h).phase, UpdatePhase.available);
    expect(state(h).problem, isNull);
  });

  test('có bản mới: mời cập nhật; trong app được khi là Android và bản phát '
      'hành kèm APK', () async {
    final h = _setup()..updates.latestRelease = release('99.0.0');
    await h.vm.autoCheck();
    expect(state(h).offer, isTrue);
    expect(state(h).inApp, isTrue);
    expect(h.vm.downloadLink, latestApkUrl);

    final iphone = _setup()
      ..updates.latestRelease = release('99.0.0')
      ..updates.canInstall = false;
    await iphone.vm.check();
    expect(state(iphone).offer, isTrue);
    expect(state(iphone).inApp, isFalse);
    // Không cài được trong app: nút chính không làm gì, chỉ có đường mở trang phát hành.
    await iphone.vm.update();
    expect(iphone.updates.downloads, isEmpty);
    expect(await iphone.vm.openDownloadLink(), isTrue);
    expect(iphone.links.opened, [releasesPageUrl]);

    final noApk = _setup()
      ..updates.latestRelease = const AppRelease(tag: 'v99.0.0');
    await noApk.vm.check();
    expect(state(noApk).inApp, isFalse);
    expect(noApk.vm.downloadLink, releasesPageUrl);
  });

  test('bản cũ hơn / bằng bản đang cài: không mời', () async {
    final h = _setup()..updates.latestRelease = release('0.9.0');
    await h.vm.check();
    expect(state(h).phase, UpdatePhase.current);
    expect(state(h).offer, isFalse);
  });

  test('cập nhật: tải (có tiến độ) → mở trình cài đặt của máy; người dùng huỷ '
      'thì bấm lại KHÔNG tải lại', () async {
    final h = _setup()
      ..updates.latestRelease = release('99.0.0')
      ..updates.downloadGate = Completer<void>();
    await h.vm.check();
    final running = h.vm.update();
    await pumpEventQueue();
    expect(state(h).phase, UpdatePhase.downloading);
    expect(state(h).progress, 0.4);
    // Đang tải: bấm kiểm tra / cập nhật lần nữa không mở thêm lượt tải.
    await h.vm.check();
    await h.vm.update();
    expect(h.updates.downloads, ['99.0.0']);
    expect(state(h).phase, UpdatePhase.downloading);

    h.updates.downloadGate!.complete();
    await running;
    expect(h.updates.installs, ['/tmp/bow-notify-99.0.0.apk']);
    // Trình cài đặt giả trả "huỷ": về bước đã tải, không lỗi.
    expect(state(h).phase, UpdatePhase.ready);
    expect(state(h).problem, isNull);

    await h.vm.update();
    expect(h.updates.downloads, ['99.0.0']);
    expect(h.updates.installs, hasLength(2));
  });

  test('tải hỏng: báo lỗi, vẫn còn mời; bấm lại thì tải lại', () async {
    final h = _setup()
      ..updates.latestRelease = release('99.0.0')
      ..updates.downloadFails = true;
    await h.vm.check();
    await h.vm.update();
    expect(state(h).phase, UpdatePhase.available);
    expect(state(h).problem, UpdateProblem.download);
    expect(h.updates.installs, isEmpty);

    h.updates.downloadFails = false;
    await h.vm.update();
    expect(h.updates.downloads, ['99.0.0', '99.0.0']);
    expect(state(h).phase, UpdatePhase.ready);
    expect(state(h).problem, isNull);
  });

  test(
    'trình cài đặt từ chối: mỗi lý do một lỗi riêng, kèm lời của máy',
    () async {
      for (final (result, problem) in [
        (InstallResult.conflict, UpdateProblem.conflict),
        (InstallResult.storage, UpdateProblem.storage),
        (InstallResult.failed, UpdateProblem.install),
      ]) {
        final h = _setup()
          ..updates.latestRelease = release('99.0.0')
          ..updates.installResult = result
          ..updates.installMessage = 'INSTALL_FAILED';
        await h.vm.check();
        await h.vm.update();
        expect(state(h).phase, UpdatePhase.ready, reason: '$result');
        expect(state(h).problem, problem);
        expect(state(h).detail, 'INSTALL_FAILED');
      }
    },
  );

  test('hộp của máy còn mở (chưa trả lời): bấm cài lại được, câu trả lời của '
      'lần trước bị bỏ', () async {
    final h = _setup()
      ..updates.latestRelease = release('99.0.0')
      ..updates.installResult = null;
    await h.vm.check();
    unawaited(h.vm.update());
    await pumpEventQueue();
    expect(state(h).phase, UpdatePhase.installing);

    h.updates
      ..installResult = InstallResult.failed
      ..installMessage = 'lần hai';
    await h.vm.update();
    expect(h.updates.installs, hasLength(2));
    expect(state(h).problem, UpdateProblem.install);
    expect(state(h).detail, 'lần hai');
  });

  test('gạt dải báo: vẫn còn mời (chấm ở Cài đặt), hỏi lại cùng bản không '
      'hiện lại, có bản mới hơn thì hiện lại', () async {
    final h = _setup()..updates.latestRelease = release('99.0.0');
    await h.vm.check();
    h.vm.hide();
    expect(state(h).hidden, isTrue);
    expect(state(h).offer, isTrue);

    await h.vm.check();
    expect(state(h).hidden, isTrue);

    h.updates.latestRelease = release('99.1.0');
    await h.vm.check();
    expect(state(h).hidden, isFalse);
    expect(state(h).release!.version, '99.1.0');
  });

  test('đã tải bản X rồi hỏi lại: cùng bản thì giữ file đã tải; ra bản mới '
      'hơn thì mời tải bản đó', () async {
    final h = _setup()..updates.latestRelease = release('99.0.0');
    await h.vm.check();
    await h.vm.update();
    expect(state(h).phase, UpdatePhase.ready);

    await h.vm.check();
    expect(state(h).phase, UpdatePhase.ready);
    expect(state(h).apkPath, '/tmp/bow-notify-99.0.0.apk');

    h.updates.latestRelease = release('99.1.0');
    await h.vm.check();
    expect(state(h).phase, UpdatePhase.available);
    expect(state(h).apkPath, isNull);
  });

  test('lần hỏi ngầm trả lời trong lúc đang tải: bị bỏ, không cắt ngang lượt '
      'tải', () async {
    final h = _setup()..updates.latestRelease = release('99.0.0');
    await h.vm.check();
    // Lần hỏi ngầm kế tiếp (đã quá hạn) đi chậm…
    h.updates
      ..latestGate = Completer<void>()
      ..downloadGate = Completer<void>();
    final silent = h.vm.check(silent: true);
    // …người dùng bấm Cập nhật trong lúc đó.
    final running = h.vm.update();
    await pumpEventQueue();
    expect(state(h).phase, UpdatePhase.downloading);

    h.updates.latestGate!.complete();
    await silent;
    expect(state(h).phase, UpdatePhase.downloading);

    h.updates.downloadGate!.complete();
    await running;
    expect(state(h).phase, UpdatePhase.ready);
  });
}
