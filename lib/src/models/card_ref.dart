import 'dart:convert';

/// Thứ gắn theo thông báo để nút bấm biết đang nói tới thẻ nào. CHỈ là mã định danh — nội dung thẻ (và cờ rủi ro) luôn
/// được đọc lại từ bản mã của server lúc bấm, không tin thứ nằm trong thông báo.
typedef CardRef = ({String topic, String port, String id, String tag});

String encodeRef(CardRef ref) =>
    jsonEncode({'t': ref.topic, 'p': ref.port, 'i': ref.id, 'g': ref.tag});

CardRef? decodeRef(String? payload) {
  try {
    final json = jsonDecode(payload ?? '');
    if (json is! Map) return null;
    final {'t': topic, 'p': port, 'i': id, 'g': tag} = json;
    if (topic is! String ||
        port is! String ||
        id is! String ||
        tag is! String) {
      return null;
    }
    return (topic: topic, port: port, id: id, tag: tag);
  } catch (_) {
    return null;
  }
}

/// Thông báo CÓ NÚT đang nằm trong khay: tag → mã thẻ + lúc hiện (mili-giây). Trên Android plugin không trả lại thứ gắn
/// theo một thông báo đang hiện, nên phải tự nhớ — để gỡ thông báo của thẻ đã được xử lý ở nơi khác (trong app, trên web):
/// không gỡ thì hai nút của nó nằm lại, bấm vào chỉ nhận được câu "thẻ không còn chờ".
typedef ShownCards = Map<String, ({String id, int at})>;

ShownCards decodeShown(String? text) {
  try {
    final json = jsonDecode(text ?? '');
    if (json is! Map) return {};
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (key is String &&
            value is Map &&
            value['i'] is String &&
            value['a'] is int)
          key: (id: value['i'] as String, at: value['a'] as int),
    };
  } catch (_) {
    return {};
  }
}

String encodeShown(ShownCards shown) => jsonEncode({
  for (final MapEntry(:key, :value) in shown.entries)
    key: {'i': value.id, 'a': value.at},
});

/// Tag của những thông báo có nút cần gỡ: thẻ của nó không còn trong [live]. Chỉ xét thông báo hiện TRƯỚC [asOf] (lúc
/// bắt đầu đọc danh sách thẻ) — thông báo hiện sau đó là của thẻ mà lần đọc này chưa kịp thấy.
List<String> staleTags(ShownCards shown, Set<String> live, int asOf) => [
  for (final MapEntry(:key, :value) in shown.entries)
    if (value.at < asOf && !live.contains(value.id)) key,
];
