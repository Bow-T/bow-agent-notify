import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/links.dart';

/// So hai số phiên bản dạng `1.2.3` (có thể kèm `v` đầu / `+số build` cuối): [latest] có MỚI hơn [current] không.
/// Chuỗi không đọc được thì coi như không mới hơn — thà không mời cập nhật còn hơn mời bậy.
bool isNewerVersion(String latest, String current) {
  List<int>? parts(String version) {
    final core = version.trim().replaceFirst(RegExp('^v'), '').split('+').first;
    final numbers = core.split('.').map(int.tryParse).toList();
    return numbers.isEmpty || numbers.contains(null)
        ? null
        : numbers.cast<int>();
  }

  final a = parts(latest);
  final b = parts(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// Hỏi GitHub bản phát hành mới nhất của app. CHỈ chạy khi người dùng bấm "Kiểm tra" — app không tự gọi ra ngoài.
class UpdateService {
  const UpdateService();

  static const _timeout = Duration(seconds: 12);

  /// Số phiên bản mới nhất đã phát hành, dạng `1.2.3`. Ném lỗi khi mất mạng / GitHub không trả lời đúng khuôn.
  Future<String> latestVersion() async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(Uri.parse(latestReleaseApi));
      // GitHub từ chối lời gọi API không có User-Agent.
      request.headers
        ..set(HttpHeaders.userAgentHeader, 'bow-notify')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(_timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('GitHub HTTP ${response.statusCode}');
      }
      final tag = (jsonDecode(body) as Map)['tag_name'];
      if (tag is! String || tag.isEmpty) {
        throw const FormatException('thiếu tag_name');
      }
      return tag.replaceFirst(RegExp('^v'), '');
    } finally {
      client.close(force: true);
    }
  }
}

final updateServiceProvider = Provider<UpdateService>(
  (ref) => const UpdateService(),
);
