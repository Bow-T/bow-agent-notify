import 'pairing.dart';

/// "Tab trên máy" — bản sao CHỈ XEM của thanh tab và hội thoại trên web bow (server: `src/core/phoneMirror.ts`).
/// Web báo cái nó đang hiện, server mã hoá rồi chép lên Realtime Database, app đọc. Không có chiều ngược lại.

String _text(Object? v) => v is String ? v : '';

/// Một tab của web.
class MirrorTab {
  const MirrorTab({
    required this.id,
    required this.title,
    required this.project,
    required this.running,
    required this.pending,
  });

  final String id;
  final String title;

  /// Tên dự án của tab (rỗng = thư mục mặc định của server).
  final String project;
  final bool running;

  /// Số thẻ đang chờ người dùng ở tab đó.
  final int pending;

  static MirrorTab? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return MirrorTab(
      id: json['id'] as String,
      title: _text(json['title']),
      project: _text(json['project']),
      running: json['running'] == true,
      pending: json['pending'] is int ? json['pending'] as int : 0,
    );
  }
}

/// Thanh tab của MỘT trang bow (một máy đã ghép + một cổng).
class MachineTabs {
  const MachineTabs({
    required this.pairing,
    required this.port,
    required this.at,
    required this.active,
    required this.tabs,
    this.can = const {},
  });

  /// Trang web báo lại ít nhất mỗi phút; quá ngần này không thấy báo = trang đã đóng / máy đã ngủ.
  static const staleAfter = Duration(seconds: 150);

  final Pairing pairing;
  final String port;

  /// Lần gần nhất trang web báo về.
  final DateTime at;

  /// Tab đang mở trên web.
  final String active;
  final List<MirrorTab> tabs;

  /// Việc điện thoại ĐƯỢC làm ngoài xem — do máy chạy bow quyết (công tắc trên web). `say` = gõ vào tab đang mở.
  final Set<String> can;

  /// Máy này cho điện thoại gõ vào tab.
  bool get canSay => can.contains('say');

  /// Dữ liệu đã cũ: trang bow trên máy không còn báo về.
  bool stale(DateTime now) => now.difference(at) > staleAfter;

  static MachineTabs? fromJson(Pairing pairing, String port, Object? json) {
    if (json is! Map || json['at'] is! int) return null;
    return MachineTabs(
      pairing: pairing,
      port: port,
      at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
      active: _text(json['active']),
      tabs: [
        for (final tab
            in (json['tabs'] is List ? json['tabs'] as List : const []))
          ?MirrorTab.fromJson(tab),
      ],
      can: {
        for (final cap
            in (json['can'] is List ? json['can'] as List : const []))
          if (cap is String) cap,
      },
    );
  }
}

/// Một dòng chat của tab, đã rút gọn (web không gửi kết quả tool, không gửi nội dung sửa).
class MirrorItem {
  const MirrorItem({
    required this.id,
    required this.kind,
    required this.text,
    required this.order,
    this.toolName = '',
    this.toolSummary = '',
    this.toolError = false,
    this.sub = '',
    this.side = '',
    this.at,
  });

  final String id;

  /// `user` / `agent` / `tool` / `result` / `error` / `system`.
  final String kind;
  final String text;

  /// Vị trí trong cả hội thoại — xếp theo số này.
  final int order;
  final String toolName;
  final String toolSummary;
  final bool toolError;

  /// Dòng của một agent phụ: việc nó đang làm.
  final String sub;

  /// Phía phát ở phiên duel / máy ở đội máy sim.
  final String side;
  final DateTime? at;

  static const _kinds = {'user', 'agent', 'tool', 'result', 'error', 'system'};

  static MirrorItem? fromJson(Object? json) {
    if (json is! Map ||
        json['id'] is! String ||
        !_kinds.contains(json['kind'])) {
      return null;
    }
    final tool = json['tool'];
    return MirrorItem(
      id: json['id'] as String,
      kind: json['kind'] as String,
      text: _text(json['text']),
      order: json['n'] is int ? json['n'] as int : 0,
      toolName: tool is Map ? _text(tool['name']) : '',
      toolSummary: tool is Map ? _text(tool['summary']) : '',
      toolError: tool is Map && tool['error'] == true,
      sub: _text(json['sub']),
      side: _text(json['side']),
      at: json['ts'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['ts'] as int)
          : null,
    );
  }
}

/// Một tab cụ thể trên một trang bow — thứ màn hội thoại cần để biết đọc ở đâu. Chỉ là ba chuỗi (so sánh bằng giá
/// trị được) — máy đã ghép tra lại theo `topic`.
typedef TabRef = ({String topic, String port, String tabId});

/// Kết quả gửi một câu từ điện thoại vào tab. `reason` = vì sao không tới (mã do máy chạy bow / tab trả về, hoặc
/// `timeout` / `denied` do app tự kết luận).
typedef SayResult = ({bool ok, String reason});
