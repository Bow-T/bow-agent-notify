import 'dart:convert';

/// Một sự kiện của luồng Realtime Database (REST, `Accept: text/event-stream`).
typedef RtdbEvent = ({String event, String data});

/// Luồng bị máy chủ đóng: luật không cho đọc nữa (`cancel`) hoặc token hết hạn (`auth_revoked`).
class RtdbStreamClosed implements Exception {
  const RtdbStreamClosed(this.event);
  final String event;
  @override
  String toString() => 'Realtime Database đóng luồng ($event)';
}

/// Giá trị mới của nhánh đang nghe sau một sự kiện. `put` thay giá trị ở `path`; `patch` trộn các khoá con ở `path`
/// (`null` = xoá khoá đó). App chỉ nghe nhánh nông (một chuỗi, hoặc một bảng khoá → chuỗi) nên `path` chỉ có thể là
/// gốc `/` hoặc một khoá con `/<khoá>`; sâu hơn thì bỏ qua. `keep-alive` và sự kiện lạ không đổi gì.
Object? applyRtdbEvent(Object? node, RtdbEvent event) {
  if (event.event == 'cancel' || event.event == 'auth_revoked') {
    throw RtdbStreamClosed(event.event);
  }
  if (event.event != 'put' && event.event != 'patch') return node;
  final Object? payload;
  try {
    payload = jsonDecode(event.data);
  } catch (_) {
    return node;
  }
  if (payload is! Map || payload['path'] is! String) return node;
  final data = payload['data'];
  final parts = (payload['path'] as String)
      .split('/')
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length > 1) return node;

  Map<String, Object?> children() => {
    if (node is Map)
      for (final MapEntry(:key, :value) in node.entries) '$key': value,
  };
  Object? orNull(Map<String, Object?> map) => map.isEmpty ? null : map;

  if (parts.isEmpty) {
    if (event.event == 'put') return data;
    if (data is! Map) return node;
    final map = children();
    for (final MapEntry(:key, :value) in data.entries) {
      value == null ? map.remove('$key') : map['$key'] = value;
    }
    return orNull(map);
  }
  final map = children();
  // `patch` ở một khoá con chỉ có nghĩa khi khoá đó là bảng — app không nghe nhánh nào như vậy; coi như `put`.
  data == null ? map.remove(parts.single) : map[parts.single] = data;
  return orNull(map);
}
