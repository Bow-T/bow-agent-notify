/// Mã ghép máy do web bow hiện thành QR (Cài đặt → Thông báo điện thoại):
/// `bowpush://pair?t=<topic>&p=<dự án Firebase>&n=<tên máy>` — khớp `pairingUri()` ở `src/core/fcm.ts` của repo bow-agent.
class Pairing {
  const Pairing({
    required this.topic,
    required this.projectId,
    required this.host,
  });

  /// Topic FCM để đăng ký nhận. Ai biết topic là nhận được thông báo — không hiện ra màn hình.
  final String topic;

  /// Dự án Firebase mà bow gửi qua. App build cho dự án KHÁC thì đăng ký vẫn "thành công" nhưng không bao giờ nhận gì.
  final String projectId;

  /// Tên máy đang chạy bow — chỉ để hiển thị.
  final String host;

  static final _topicPattern = RegExp(r'^bow-[0-9a-f]{32}$');

  /// `null` khi chuỗi không phải mã ghép của bow (QR lạ, dán nhầm).
  static Pairing? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'bowpush' || uri.host != 'pair') {
      return null;
    }
    final topic = uri.queryParameters['t'] ?? '';
    final projectId = uri.queryParameters['p'] ?? '';
    if (!_topicPattern.hasMatch(topic) || projectId.isEmpty) return null;
    return Pairing(
      topic: topic,
      projectId: projectId,
      host: uri.queryParameters['n'] ?? '',
    );
  }

  /// Chuỗi để lưu lại — cùng khuôn với mã ghép nên đọc lại bằng [parse].
  String get uri => Uri(
    scheme: 'bowpush',
    host: 'pair',
    queryParameters: {'t': topic, 'p': projectId, 'n': host},
  ).toString();
}
