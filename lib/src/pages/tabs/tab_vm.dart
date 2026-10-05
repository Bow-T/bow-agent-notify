import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mirror.dart';
import '../../models/pairing.dart';
import '../../services/mirror_service.dart';
import '../../utils/l10n.dart';
import 'tabs_vm.dart';
import 'typing_gate.dart';

/// Trạng thái màn hội thoại của một tab.
@immutable
class TabState {
  const TabState({this.items = const [], this.loaded = false, this.sending});

  /// Các dòng cuối của tab (cũ → mới).
  final List<MirrorItem> items;

  /// Đã nhận được dữ liệu lần đầu (kể cả khi tab trống).
  final bool loaded;

  /// Câu đang gửi từ điện thoại (chưa có báo lại) — hiện mờ ở cuối hội thoại, ô nhập bị khoá.
  final String? sending;

  TabState copyWith({
    List<MirrorItem>? items,
    bool? loaded,
    String? Function()? sending,
  }) => TabState(
    items: items ?? this.items,
    loaded: loaded ?? this.loaded,
    sending: sending == null ? this.sending : sending(),
  );
}

/// Câu nói với người dùng khi một lệnh không tới được tab.
String sayFailure(String reason) => switch (reason) {
  'no-web' => t(
    'Trang bow trên máy không nhận lệnh — trang có đang mở không?',
    'The bow page on the machine did not pick this up — is it open?',
  ),
  'no-answer' => t(
    'Tab trên máy không phản hồi.',
    'The tab on the machine did not respond.',
  ),
  'tab-closed' => t(
    'Tab này đã đóng trên máy.',
    'This tab was closed on the machine.',
  ),
  'attachments' => t(
    'Khung soạn của tab đó trên máy đang có tệp đính kèm — gửi hoặc gỡ chúng ở máy trước.',
    'That tab has attachments waiting in its composer — send or remove them on the machine first.',
  ),
  'stale' => t(
    'Đồng hồ điện thoại lệch quá 3 phút so với máy chạy bow — chỉnh lại giờ rồi gửi lại.',
    'The phone clock is more than 3 minutes off from the machine — fix the time and resend.',
  ),
  'denied' => t(
    'Máy đó chưa bật "Cho gõ vào tab từ điện thoại".',
    'That machine has not enabled "Let the phone type into tabs".',
  ),
  'no-project' => t(
    'Dự án đó không còn trên máy.',
    'That project is no longer on the machine.',
  ),
  'timeout' => t(
    'Không thấy máy chạy bow trả lời (mất mạng, hoặc quyền gõ vừa bị tắt).',
    'No answer from the machine (network down, or typing was just turned off).',
  ),
  _ => t('Máy chạy bow từ chối lệnh.', 'The machine refused the command.'),
};

/// ViewModel màn hội thoại của MỘT tab: nghe các dòng cuối theo luồng, và — khi máy cho phép — gửi một câu vào tab đó.
class TabVm extends Notifier<TabState> {
  TabVm(this.tab);

  final TabRef tab;
  StreamSubscription<List<MirrorItem>>? _sub;

  Pairing? get _pairing => ref
      .read(mirrorPairingsProvider)
      .where((p) => p.topic == tab.topic)
      .firstOrNull;

  @override
  TabState build() {
    ref.onDispose(paused);
    resumed();
    return const TabState();
  }

  void resumed() {
    if (_sub != null) return;
    final pairing = _pairing;
    if (pairing == null) return; // máy vừa bị bỏ ghép
    _sub = ref
        .read(mirrorServiceProvider)
        .watchChat(pairing, tab.port, tab.tabId)
        .listen((items) {
          if (ref.mounted) state = state.copyWith(items: items, loaded: true);
        });
  }

  void paused() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /// Gửi [text] vào tab này. Trả `null` khi tab trên máy đã nhận (câu sẽ hiện trong hội thoại sau vài giây), hoặc câu
  /// báo lỗi. Phải mở khoá gõ trước (vân tay, một lần cho 5 phút); không mở được thì không gửi gì và trả `''`
  /// (không có gì để báo — người dùng tự huỷ).
  Future<String?> send(
    String text, {
    required Future<bool> Function() askFallback,
  }) async {
    final clean = text.trim();
    final pairing = _pairing;
    if (clean.isEmpty || state.sending != null) return '';
    if (pairing == null) return sayFailure('denied');
    final unlocked = await ref
        .read(typingGateProvider.notifier)
        .ensure(askFallback: askFallback);
    if (!unlocked || !ref.mounted) return '';
    state = state.copyWith(sending: () => clean);
    try {
      final result = await ref
          .read(mirrorServiceProvider)
          .say(pairing, tab.port, tab.tabId, clean);
      return result.ok ? null : sayFailure(result.reason);
    } catch (e) {
      return t('Không gửi được: $e', 'Could not send: $e');
    } finally {
      if (ref.mounted) state = state.copyWith(sending: () => null);
    }
  }
}

final tabVmProvider = NotifierProvider.family<TabVm, TabState, TabRef>(
  TabVm.new,
  isAutoDispose: true,
);
