import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mirror.dart';
import '../../models/pairing.dart';
import '../../services/mirror_service.dart';
import '../home/home_vm.dart';

/// Các máy đã ghép CÓ khoá — chỉ những máy đó mới giải mã được bản sao tab. Tách thành provider riêng để ViewModel
/// dưới đây chỉ dựng lại khi danh sách này đổi (và để test thay được).
final mirrorPairingsProvider = Provider<List<Pairing>>(
  (ref) => [
    for (final pairing in ref.watch(
      homeVmProvider.select((state) => state.pairings),
    ))
      if (pairing.canApprove) pairing,
  ],
);

/// ViewModel "Tab trên máy": thanh tab của từng trang bow (máy đã ghép × cổng), cập nhật theo luồng. Chỉ đọc.
class TabsVm extends Notifier<List<MachineTabs>> {
  /// Dò lại xem máy nào / cổng nào đang có bản sao; cũng là nhịp để màn hình tính lại "dữ liệu đã cũ".
  static const _rescan = Duration(seconds: 30);

  final Map<String, StreamSubscription<MachineTabs?>> _subs = {};
  final Map<String, MachineTabs> _latest = {};
  Timer? _timer;
  List<Pairing> _pairings = const [];

  MirrorService get _mirror => ref.read(mirrorServiceProvider);

  @override
  List<MachineTabs> build() {
    _pairings = ref.watch(mirrorPairingsProvider);
    ref.onDispose(paused);
    // Dựng lại (danh sách máy đổi): bỏ hết luồng cũ, nghe lại từ đầu.
    paused();
    _latest.clear();
    resumed();
    return const [];
  }

  /// App trở lại trước mặt (hoặc vừa dựng): dò máy + nghe luồng.
  void resumed() {
    if (_timer != null) return;
    _timer = Timer.periodic(_rescan, (_) => unawaited(_scan()));
    unawaited(_scan());
  }

  /// App khuất: đóng mọi luồng (không giữ kết nối khi không ai nhìn). Dữ liệu đang có vẫn giữ để hiện lại ngay.
  void paused() {
    _timer?.cancel();
    _timer = null;
    for (final sub in _subs.values) {
      unawaited(sub.cancel());
    }
    _subs.clear();
  }

  Future<void> _scan() async {
    final wanted = <String>{};
    for (final pairing in _pairings) {
      final List<String> ports;
      try {
        ports = await _mirror.ports(pairing);
      } catch (_) {
        // Mất mạng: giữ nguyên các luồng đang có của máy này (chúng tự nối lại).
        wanted.addAll(
          _subs.keys.where((key) => key.startsWith('${pairing.topic}|')),
        );
        continue;
      }
      if (!ref.mounted || _timer == null) return;
      for (final port in ports) {
        final key = '${pairing.topic}|$port';
        wanted.add(key);
        _subs[key] ??= _mirror
            .watchTabs(pairing, port)
            .listen((tabs) => _set(key, tabs));
      }
    }
    if (!ref.mounted || _timer == null) return;
    for (final key in _subs.keys.where((k) => !wanted.contains(k)).toList()) {
      unawaited(_subs.remove(key)?.cancel());
      _latest.remove(key);
    }
    _emit(); // kể cả khi không đổi: màn hình tính lại "đã cũ" theo giờ hiện tại
  }

  void _set(String key, MachineTabs? tabs) {
    if (!ref.mounted) return;
    tabs == null ? _latest.remove(key) : _latest[key] = tabs;
    _emit();
  }

  void _emit() {
    state = _latest.values.toList()
      ..sort(
        (a, b) => '${a.pairing.host}|${a.port}'.compareTo(
          '${b.pairing.host}|${b.port}',
        ),
      );
  }
}

final tabsVmProvider = NotifierProvider<TabsVm, List<MachineTabs>>(TabsVm.new);
