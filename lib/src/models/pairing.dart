/// Mã ghép máy do web bow hiện thành QR (Cài đặt → Thông báo điện thoại):
/// `bowpush://pair?t=<topic>&p=<dự án Firebase>&n=<tên máy>[&k=<khoá>&d=<máy chủ cơ sở dữ liệu>]` — khớp
/// `pairingUri()` ở `src/core/fcm.ts` của repo bow-agent.
class Pairing {
  const Pairing({
    required this.topic,
    required this.projectId,
    required this.host,
    this.key,
    this.dbHost,
  });

  /// Topic FCM để đăng ký nhận. Ai biết topic là nhận được thông báo — không hiện ra màn hình.
  final String topic;

  /// Dự án Firebase mà bow gửi qua. App build cho dự án KHÁC thì đăng ký vẫn "thành công" nhưng không bao giờ nhận gì.
  final String projectId;

  /// Tên máy đang chạy bow — chỉ để hiển thị.
  final String host;

  /// Khoá ghép máy (32 byte, base64url) — có khi máy đó bật "duyệt từ điện thoại". Mọi thẻ / quyết định gửi qua lại
  /// đều mã hoá bằng khoá này; ai có nó là DUYỆT được, nên không bao giờ hiện ra màn hình hay ghi log.
  final String? key;

  /// Máy chủ Realtime Database chứa thẻ chờ duyệt (đi cùng [key]).
  final String? dbHost;

  /// Máy này cho duyệt từ điện thoại.
  bool get canApprove => key != null && dbHost != null;

  static final _topicPattern = RegExp(r'^bow-[0-9a-f]{32}$');
  static final _keyPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static final _dbHostPattern = RegExp(
    r'^[a-z0-9-]+(\.[a-z0-9-]+)*\.(firebaseio\.com|firebasedatabase\.app)$',
  );

  /// `null` khi chuỗi không phải mã ghép của bow (QR lạ, dán nhầm).
  static Pairing? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'bowpush' || uri.host != 'pair') {
      return null;
    }
    final topic = uri.queryParameters['t'] ?? '';
    final projectId = uri.queryParameters['p'] ?? '';
    if (!_topicPattern.hasMatch(topic) || projectId.isEmpty) return null;
    // Khoá + máy chủ phải đi CẶP và đúng khuôn; thiếu / sai thì coi như máy chỉ báo (không đoán bừa nơi gửi quyết định).
    final key = uri.queryParameters['k'] ?? '';
    final dbHost = uri.queryParameters['d'] ?? '';
    final remote = _keyPattern.hasMatch(key) && _dbHostPattern.hasMatch(dbHost);
    return Pairing(
      topic: topic,
      projectId: projectId,
      host: uri.queryParameters['n'] ?? '',
      key: remote ? key : null,
      dbHost: remote ? dbHost : null,
    );
  }

  /// Chuỗi để lưu lại — cùng khuôn với mã ghép nên đọc lại bằng [parse].
  String get uri => Uri(
    scheme: 'bowpush',
    host: 'pair',
    queryParameters: {
      't': topic,
      'p': projectId,
      'n': host,
      if (canApprove) ...{'k': key!, 'd': dbHost!},
    },
  ).toString();
}
