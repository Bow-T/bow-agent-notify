import 'package:bow_notify/src/models/appearance.dart';
import 'package:bow_notify/src/pages/settings/appearance_vm.dart';
import 'package:bow_notify/src/services/appearance_store.dart';
import 'package:bow_notify/src/themes/bow_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ViewModel của lựa chọn giao diện, chạy với kho lưu GIẢ.

class FakeAppearanceStore implements AppearanceStore {
  FakeAppearanceStore([this.saved = defaultAppearance]);
  Appearance saved;
  bool broken = false;
  int saves = 0;

  @override
  Future<Appearance> load() async {
    if (broken) throw Exception('đĩa hỏng');
    return saved;
  }

  @override
  Future<void> save(Appearance appearance) async {
    saves++;
    if (broken) throw Exception('đĩa hỏng');
    saved = appearance;
  }
}

({ProviderContainer container, FakeAppearanceStore store}) _setup([
  Appearance saved = defaultAppearance,
]) {
  final store = FakeAppearanceStore(saved);
  final container = ProviderContainer(
    overrides: [appearanceStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return (container: container, store: store);
}

void main() {
  test('mặc định là kính theo máy; nạp lại đúng lựa chọn đã lưu', () async {
    final h = _setup((style: BowStyle.brutal, mode: GlassMode.dark));
    expect(h.container.read(appearanceVmProvider), defaultAppearance);
    await h.container.read(appearanceVmProvider.notifier).load();
    expect(h.container.read(appearanceVmProvider), (
      style: BowStyle.brutal,
      mode: GlassMode.dark,
    ));
  });

  test('đổi phong cách / chế độ màu: áp ngay và lưu; chọn lại cái đang có thì '
      'không ghi', () async {
    final h = _setup();
    final vm = h.container.read(appearanceVmProvider.notifier);
    vm.setStyle(BowStyle.brutal);
    vm.setMode(GlassMode.light);
    await pumpEventQueue();
    expect(h.store.saved, (style: BowStyle.brutal, mode: GlassMode.light));
    expect(h.store.saves, 2);
    vm.setStyle(BowStyle.brutal);
    await pumpEventQueue();
    expect(h.store.saves, 2);
  });

  test('kho lưu hỏng: nạp thì giữ mặc định, đổi thì vẫn có hiệu lực', () async {
    final h = _setup((style: BowStyle.brutal, mode: GlassMode.dark));
    h.store.broken = true;
    final vm = h.container.read(appearanceVmProvider.notifier);
    await vm.load();
    expect(h.container.read(appearanceVmProvider), defaultAppearance);
    vm.setStyle(BowStyle.brutal);
    await pumpEventQueue();
    expect(h.container.read(appearanceVmProvider).style, BowStyle.brutal);
  });
}
