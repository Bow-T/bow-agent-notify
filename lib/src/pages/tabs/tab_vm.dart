import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mirror.dart';
import '../../services/mirror_service.dart';
import 'tabs_vm.dart';

/// Trạng thái màn hội thoại của một tab.
@immutable
class TabState {
  const TabState({this.items = const [], this.loaded = false});

  /// Các dòng cuối của tab (cũ → mới).
  final List<MirrorItem> items;

  /// Đã nhận được dữ liệu lần đầu (kể cả khi tab trống).
  final bool loaded;
}

/// ViewModel màn hội thoại của MỘT tab: nghe các dòng cuối theo luồng. Chỉ đọc — không gửi gì về máy.
class TabVm extends Notifier<TabState> {
  TabVm(this.tab);

  final TabRef tab;
  StreamSubscription<List<MirrorItem>>? _sub;

  @override
  TabState build() {
    ref.onDispose(paused);
    resumed();
    return const TabState();
  }

  void resumed() {
    if (_sub != null) return;
    final pairing = ref
        .read(mirrorPairingsProvider)
        .where((p) => p.topic == tab.topic)
        .firstOrNull;
    if (pairing == null) return; // máy vừa bị bỏ ghép
    _sub = ref
        .read(mirrorServiceProvider)
        .watchChat(pairing, tab.port, tab.tabId)
        .listen((items) {
          if (ref.mounted) state = TabState(items: items, loaded: true);
        });
  }

  void paused() {
    unawaited(_sub?.cancel());
    _sub = null;
  }
}

final tabVmProvider = NotifierProvider.family<TabVm, TabState, TabRef>(
  TabVm.new,
  isAutoDispose: true,
);
