import 'package:bow_notify/src/pages/tabs/typing_gate.dart';
import 'package:bow_notify/src/services/biometric_service.dart';
import 'package:bow_notify/src/services/prefs_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tabs_vm_test.dart' show FakeBiometric;

// Thời gian một lần mở khoá gõ (Cài đặt → Bảo mật), chạy với kho lưu GIẢ.

class FakePrefs implements PrefsStore {
  final ints = <String, int>{};
  bool broken = false;

  @override
  Future<int?> readInt(String key) async {
    if (broken) throw Exception('đĩa hỏng');
    return ints[key];
  }

  @override
  Future<void> writeInt(String key, int value) async {
    if (broken) throw Exception('đĩa hỏng');
    ints[key] = value;
  }
}

({ProviderContainer container, FakePrefs prefs}) _setup() {
  final prefs = FakePrefs();
  final container = ProviderContainer(
    overrides: [
      prefsStoreProvider.overrideWithValue(prefs),
      biometricServiceProvider.overrideWithValue(FakeBiometric()),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, prefs: prefs);
}

void main() {
  test('mặc định 5 phút; chọn mức khác thì lưu và nạp lại được', () async {
    final h = _setup();
    expect(h.container.read(unlockMinutesProvider), 5);
    h.container.read(unlockMinutesProvider.notifier).set(15);
    await pumpEventQueue();
    expect(h.prefs.ints, {'unlock_minutes': 15});

    final again = ProviderContainer(
      overrides: [prefsStoreProvider.overrideWithValue(h.prefs)],
    );
    addTearDown(again.dispose);
    await again.read(unlockMinutesProvider.notifier).load();
    expect(again.read(unlockMinutesProvider), 15);
  });

  test(
    'mức lạ (không nằm trong các lựa chọn) bị bỏ: cả khi chọn lẫn khi nạp',
    () async {
      final h = _setup();
      h.container.read(unlockMinutesProvider.notifier).set(60);
      expect(h.container.read(unlockMinutesProvider), 5);
      h.prefs.ints['unlock_minutes'] = 999;
      await h.container.read(unlockMinutesProvider.notifier).load();
      expect(h.container.read(unlockMinutesProvider), 5);
    },
  );

  test('kho lưu hỏng: giữ mặc định, chọn vẫn có hiệu lực', () async {
    final h = _setup()..prefs.broken = true;
    await h.container.read(unlockMinutesProvider.notifier).load();
    expect(h.container.read(unlockMinutesProvider), 5);
    h.container.read(unlockMinutesProvider.notifier).set(1);
    await pumpEventQueue();
    expect(h.container.read(unlockMinutesProvider), 1);
  });

  test('phiên mở khoá gõ dài đúng mức đã chọn', () async {
    final h = _setup();
    h.container.read(unlockMinutesProvider.notifier).set(1);
    final before = DateTime.now();
    final ok = await h.container
        .read(typingGateProvider.notifier)
        .ensure(askFallback: () async => false);
    expect(ok, isTrue);
    final until = h.container.read(typingGateProvider)!;
    expect(until.difference(before).inSeconds, inInclusiveRange(59, 61));

    // Đổi mức không kéo dài phiên đang mở; lần mở khoá kế mới theo mức mới.
    h.container.read(unlockMinutesProvider.notifier).set(15);
    expect(h.container.read(typingGateProvider), until);
    h.container.read(typingGateProvider.notifier).unlockNow();
    expect(
      h.container.read(typingGateProvider)!.difference(before).inMinutes,
      inInclusiveRange(14, 15),
    );
  });
}
