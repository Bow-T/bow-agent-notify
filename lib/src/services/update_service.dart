import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/links.dart';
import '../models/app_release.dart';

/// Trình cài đặt của máy trả lời gì sau khi app đưa file APK cho nó.
enum InstallResult {
  /// Đã cài xong (hiếm khi thấy: cài đè lên chính mình thì app bị tắt trước khi kịp nhận).
  done,

  /// Người dùng bấm Huỷ ở hộp của máy, hoặc chưa cho app quyền cài ứng dụng.
  cancelled,

  /// Bản mới ký bằng khoá KHÁC bản đang cài — Android không cho cài đè.
  conflict,

  /// Máy hết chỗ trống.
  storage,

  /// Lý do khác (file hỏng, máy chặn cài, …).
  failed,
}

/// File tạm giữ phần ĐANG tải của [target] — mạng đứt giữa chừng thì lần sau tải tiếp từ đây.
File partOf(File target) => File('${target.path}.part');

/// Ghi [body] vào [target] và chỉ để lại file khi nó ĐÚNG là bản phát hành: đủ [size] byte và — nếu bản phát hành có
/// khai — khớp mã băm [sha256]. Ghi qua file `.part` rồi mới đổi tên, nên file mang tên [target] luôn là file đã kiểm.
///
/// [resumeFrom] > 0 = [body] là phần CÒN LẠI kể từ byte đó, nối vào file `.part` đã có (mã băm vẫn tính trên cả
/// file). Luồng đứt giữa chừng (mất mạng) thì GIỮ phần đã ghi để lần sau tải tiếp; còn file sai — thừa, thiếu, lệch mã
/// băm — thì xoá và ném [FormatException].
Future<void> saveVerified(
  Stream<List<int>> body,
  File target, {
  required int size,
  String? sha256,
  int resumeFrom = 0,
  void Function(int received)? onProgress,
}) async {
  final part = partOf(target);
  final hash = Sha256().newHashSink();
  var received = 0;
  try {
    if (resumeFrom > 0) {
      await for (final chunk in part.openRead(0, resumeFrom)) {
        hash.add(chunk);
        received += chunk.length;
      }
      if (received != resumeFrom) {
        throw const FormatException('phần tải dở không còn nguyên');
      }
    }
    final sink = part.openWrite(
      mode: resumeFrom > 0 ? FileMode.append : FileMode.write,
    );
    try {
      await sink.addStream(
        body.map((chunk) {
          received += chunk.length;
          // Dừng ngay khi vượt kích thước đã khai — không để một nguồn sai ghi đầy bộ nhớ máy.
          if (received > size) {
            throw const FormatException('file lớn hơn bản phát hành');
          }
          hash.add(chunk);
          onProgress?.call(received);
          return chunk;
        }),
      );
    } finally {
      // Luồng hỏng thì `close` ném lại đúng lỗi đó — lỗi gốc đã đang đi lên rồi.
      await sink.close().catchError((Object _) {});
    }
    if (received != size) {
      throw const FormatException('file tải về thiếu');
    }
    hash.close();
    final digest = (await hash.hash()).bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    if (sha256 != null && digest != sha256) {
      throw const FormatException('file tải về không khớp bản phát hành');
    }
    await part.rename(target.path);
  } on FormatException {
    try {
      await part.delete();
    } catch (_) {
      // Chưa kịp tạo.
    }
    rethrow;
  }
}

/// Bản mới của app: hỏi GitHub Releases, tải APK về vùng riêng của app, rồi đưa cho trình cài đặt của máy (Android).
/// iPhone không cài được APK — ở đó chỉ hỏi phiên bản.
class UpdateService {
  const UpdateService();

  static const _channel = MethodChannel('dev.bow.bow_notify/update');
  static const _timeout = Duration(seconds: 12);

  /// Mạng đứng lâu ngần này giữa hai mẩu dữ liệu thì coi như lượt tải đó hỏng.
  static const _stall = Duration(seconds: 30);

  /// Số lượt tải cho một lần bấm: mạng đứt / đổi wifi ↔ 4G giữa chừng thì tự tải TIẾP phần còn lại.
  static const _attempts = 3;

  /// Máy này tự tải + cài được bản mới ngay trong app.
  bool get canInstall => defaultTargetPlatform == TargetPlatform.android;

  /// [from] > 0 = chỉ xin phần từ byte đó trở đi (tải tiếp); máy chủ chịu thì trả 206, không thì trả cả file (200).
  Future<HttpClientResponse> _get(
    HttpClient client,
    Uri url, {
    int from = 0,
  }) async {
    final request = await client.getUrl(url);
    // GitHub từ chối lời gọi API không có User-Agent.
    request.headers.set(HttpHeaders.userAgentHeader, 'bow-notify');
    if (from > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-');
    final response = await request.close().timeout(_timeout);
    final ok =
        response.statusCode == HttpStatus.ok ||
        (from > 0 && response.statusCode == HttpStatus.partialContent);
    if (!ok) {
      throw HttpException('GitHub HTTP ${response.statusCode}', uri: url);
    }
    return response;
  }

  /// Bản phát hành mới nhất. Ném lỗi khi mất mạng / GitHub không trả lời đúng khuôn.
  Future<AppRelease> latest() async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final response = await _get(client, Uri.parse(latestReleaseApi));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      return AppRelease.fromGitHub(jsonDecode(body));
    } finally {
      client.close(force: true);
    }
  }

  /// Tải APK của [release] về thư mục tạm RIÊNG của app (app khác không đọc / sửa được), trả đường dẫn file đã kiểm.
  /// Bản đã tải đủ từ trước thì dùng lại, bản tải DỞ thì tải tiếp (cả khi lần trước app bị tắt giữa chừng); bản tải
  /// của phiên bản khác bị dọn.
  Future<String> download(
    AppRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final size = release.apkSize;
    if (size == null) throw StateError('bản phát hành không kèm APK');
    final dir = Directory.systemTemp;
    final target = File('${dir.path}/bow-notify-${release.version}.apk');
    final part = partOf(target);
    await for (final entry in dir.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is! File ||
          !name.startsWith('bow-notify-') ||
          entry.path == target.path ||
          entry.path == part.path) {
        continue;
      }
      try {
        await entry.delete();
      } catch (_) {
        // Không xoá được thì thôi — hệ điều hành tự dọn thư mục tạm.
      }
    }
    if (await target.exists() && await target.length() == size) {
      return target.path;
    }
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      for (var attempt = 1; ; attempt++) {
        try {
          var have = await part.exists() ? await part.length() : 0;
          // Phần dở dài bằng / hơn cả file thì không phải của bản này — bỏ, tải lại từ đầu.
          if (have >= size) {
            await part.delete();
            have = 0;
          }
          final response = await _get(client, apkUri(release.tag), from: have);
          await saveVerified(
            response.timeout(_stall),
            target,
            size: size,
            sha256: release.apkSha256,
            resumeFrom: response.statusCode == HttpStatus.partialContent
                ? have
                : 0,
            onProgress: (received) => onProgress?.call(received, size),
          );
          return target.path;
        } on FormatException {
          // File sai (không phải mạng): tải lại cũng thế — báo luôn.
          rethrow;
        } catch (_) {
          if (attempt >= _attempts) rethrow;
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } finally {
      client.close(force: true);
    }
  }

  /// Đưa file APK ở [path] cho trình cài đặt của máy và chờ nó trả lời. Máy LUÔN hỏi người dùng trước khi cài; cài
  /// xong thì app bị tắt để thay bản mới, nên thường không có câu trả lời "xong".
  Future<({InstallResult result, String? message})> install(String path) async {
    final reply = await _channel.invokeMapMethod<String, Object?>('install', {
      'path': path,
    });
    final result = switch (reply?['status']) {
      'done' => InstallResult.done,
      'cancelled' => InstallResult.cancelled,
      'conflict' => InstallResult.conflict,
      'storage' => InstallResult.storage,
      _ => InstallResult.failed,
    };
    final message = reply?['message'];
    return (result: result, message: message is String ? message : null);
  }
}

final updateServiceProvider = Provider<UpdateService>(
  (ref) => const UpdateService(),
);
