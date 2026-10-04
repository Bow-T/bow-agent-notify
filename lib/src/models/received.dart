/// Một thông báo đã tới lúc app đang mở.
typedef Received = ({String kind, String title, String body, DateTime at});

/// Icon 3D của từng loại thông báo (`data.kind` do server gửi: approval / question / done / fatal / test) — cùng hình
/// với web bow: khiên = chờ duyệt, bong bóng = đang hỏi, bi xanh = xong, bi đỏ = lỗi.
String kindIcon(String kind) => switch (kind) {
  'approval' => 'shield',
  'question' => 'chat',
  'done' => 'success',
  'fatal' => 'error',
  _ => 'bolt',
};
