import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mirror.dart';
import '../models/pairing.dart';
import '../models/rtdb_event.dart';
import 'remote_service.dart';

/// Đọc "tab trên máy" (models/mirror.dart) từ Realtime Database của máy đã ghép. Chỉ ĐỌC.
///
/// Nghe kiểu LUỒNG chứ không hỏi theo nhịp: đo thật, server ghi → app nhận ~250 ms, và app chỉ tải phần đổi (mỗi dòng
/// chat một khoá). Luồng tự nối lại khi rớt mạng; người nghe huỷ đăng ký là luồng đóng.
class MirrorService {
  const MirrorService(this._remote);

  final RemoteService _remote;

  static const _timeout = Duration(seconds: 12);

  /// Realtime Database gửi `keep-alive` mỗi ~30 giây; im lâu hơn ngần này là đường truyền đã chết (đổi mạng, máy ngủ).
  static const _silence = Duration(seconds: 75);
  static const _retry = Duration(seconds: 3);

  /// Database từ chối đọc (luật chưa có nhánh `mirror` — máy chưa bật tính năng): thử lại thưa hơn.
  static const _retryDenied = Duration(seconds: 30);

  Uri _url(Pairing pairing, String path, [Map<String, String>? query]) =>
      Uri.https(
        pairing.dbHost!,
        '/bow/${pairing.topic}/mirror$path.json',
        query,
      );

  /// Các cổng (tiến trình bow) đang có bản sao trên máy [pairing]. Rỗng = máy đó chưa bật "xem tab trên điện thoại".
  Future<List<String>> ports(Pairing pairing) async {
    if (!pairing.canApprove) return const [];
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client
          .getUrl(_url(pairing, '', {'shallow': 'true'}))
          .timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(body);
      return data is Map ? [for (final key in data.keys) '$key'] : const [];
    } finally {
      client.close(force: true);
    }
  }

  /// Thanh tab của một trang bow, cập nhật khi đổi. `null` = không còn bản sao (tính năng vừa tắt / đổi mã ghép).
  Stream<MachineTabs?> watchTabs(Pairing pairing, String port) =>
      _watch(_url(pairing, '/$port/tabs')).asyncMap((node) async {
        if (node is! String) return null;
        return MachineTabs.fromJson(
          pairing,
          port,
          await _remote.openMirror(pairing, 'tabs', node),
        );
      });

  /// Các dòng cuối của một tab, đã xếp thứ tự, cập nhật khi đổi. Dòng không mở được bằng khoá bị bỏ qua.
  Stream<List<MirrorItem>> watchChat(
    Pairing pairing,
    String port,
    String tabId,
  ) {
    // Giải mã rồi nhớ lại theo bản mã: mỗi sự kiện chỉ đổi một vài dòng, không giải mã lại cả bốn chục dòng.
    final opened = <String, MirrorItem?>{};
    return _watch(_url(pairing, '/$port/chat/$tabId')).asyncMap((node) async {
      final blobs = node is Map ? node : const <Object?, Object?>{};
      final items = <MirrorItem>[];
      final seen = <String>{};
      for (final MapEntry(:key, :value) in blobs.entries) {
        if (value is! String) continue;
        seen.add(value);
        final item = opened.containsKey(value)
            ? opened[value]
            : opened[value] = MirrorItem.fromJson(
                await _remote.openMirror(pairing, '$tabId/$key', value),
              );
        if (item != null) items.add(item);
      }
      opened.removeWhere((blob, _) => !seen.contains(blob));
      return items..sort((a, b) => a.order.compareTo(b.order));
    });
  }

  /// Giá trị của một nhánh, phát lại mỗi khi nó đổi. Rớt mạng thì tự nối lại (và phát lại giá trị đầy đủ).
  Stream<Object?> _watch(Uri url) async* {
    while (true) {
      final client = HttpClient()..connectionTimeout = _timeout;
      var wait = _retry;
      try {
        final request = await client.getUrl(url).timeout(_timeout);
        request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
        final response = await request.close().timeout(_timeout);
        if (response.statusCode != 200) {
          if (response.statusCode == 401 || response.statusCode == 403) {
            wait = _retryDenied;
          }
          throw HttpException('HTTP ${response.statusCode}');
        }
        Object? node;
        String name = '';
        final lines = response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(_silence);
        await for (final line in lines) {
          if (line.startsWith('event:')) {
            name = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            final before = node;
            node = applyRtdbEvent(node, (
              event: name,
              data: line.substring(5).trim(),
            ));
            if (name == 'put' || name == 'patch' || !identical(before, node)) {
              yield node;
            }
          }
        }
      } catch (_) {
        // rớt mạng / máy chủ đóng luồng: nối lại ở dưới
      } finally {
        client.close(force: true);
      }
      await Future<void>.delayed(wait);
    }
  }
}

final mirrorServiceProvider = Provider<MirrorService>(
  (ref) => MirrorService(ref.watch(remoteServiceProvider)),
);
