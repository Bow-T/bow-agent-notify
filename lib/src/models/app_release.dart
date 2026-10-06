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

/// Một bản phát hành của app trên GitHub Releases.
class AppRelease {
  const AppRelease({
    required this.tag,
    this.notes = '',
    this.apkSize,
    this.apkSha256,
  });

  /// Tag nguyên văn (`v1.2.3`) — địa chỉ tải APK ghép từ đây.
  final String tag;

  /// Ghi chú "có gì mới" người phát hành viết (Markdown).
  final String notes;

  /// Kích thước file APK tính bằng byte; `null` = bản phát hành không kèm APK (không cập nhật trong app được).
  final int? apkSize;

  /// Mã băm SHA-256 của APK (hex thường) do GitHub tính lúc tải lên; bản phát hành cũ không có.
  final String? apkSha256;

  /// Số phiên bản dạng `1.2.3`.
  String get version => tag.replaceFirst(RegExp('^v'), '');

  bool get hasApk => apkSize != null;

  /// Đọc câu trả lời của `GET /repos/<repo>/releases/latest`. Sai khuôn thì ném [FormatException].
  factory AppRelease.fromGitHub(Object? json) {
    if (json is! Map) throw const FormatException('không phải object');
    final tag = json['tag_name'];
    // Tag phải là một số phiên bản (`v1.2.3`): thứ khác thì không so được với bản đang cài, và không được đem đi
    // ghép địa chỉ tải.
    if (tag is! String || !RegExp(r'^v?\d+(\.\d+)*$').hasMatch(tag)) {
      throw const FormatException('tag_name không phải số phiên bản');
    }
    int? size;
    String? sha256;
    final assets = json['assets'];
    for (final asset in assets is List ? assets : const <Object?>[]) {
      if (asset is! Map || asset['name'] != apkAssetName) continue;
      final bytes = asset['size'];
      if (bytes is! int || bytes <= 0) continue;
      size = bytes;
      final digest = asset['digest'];
      if (digest is String &&
          RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(digest)) {
        sha256 = digest.substring('sha256:'.length);
      }
    }
    final body = json['body'];
    return AppRelease(
      tag: tag,
      notes: body is String ? body.trim() : '',
      apkSize: size,
      apkSha256: sha256,
    );
  }
}
