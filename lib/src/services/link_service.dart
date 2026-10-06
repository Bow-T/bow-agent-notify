import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mở một link bằng trình duyệt của máy (tải APK bản mới, đọc tài liệu trên GitHub).
class LinkService {
  const LinkService();

  /// `false` = máy không mở được (không có trình duyệt).
  Future<bool> open(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

final linkServiceProvider = Provider<LinkService>((ref) => const LinkService());
