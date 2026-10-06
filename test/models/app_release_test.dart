import 'package:bow_notify/src/constants/links.dart';
import 'package:bow_notify/src/models/app_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('so phiên bản: theo từng số, không theo chữ', () {
    expect(isNewerVersion('1.12.0', '1.11.0'), isTrue);
    expect(
      isNewerVersion('1.10.0', '1.9.1'),
      isTrue,
    ); // so chữ thì "1.10" < "1.9"
    expect(isNewerVersion('2.0.0', '1.99.99'), isTrue);
    expect(isNewerVersion('1.11.1', '1.11.0'), isTrue);
    expect(isNewerVersion('1.11.0', '1.11.0'), isFalse);
    expect(isNewerVersion('1.10.9', '1.11.0'), isFalse);
  });

  test('chấp nhận tiền tố v, số build và độ dài khác nhau', () {
    expect(isNewerVersion('v1.12.0', '1.11.0+16'), isTrue);
    expect(isNewerVersion('1.12', '1.11.5'), isTrue);
    expect(isNewerVersion('1.11', '1.11.0'), isFalse);
    expect(isNewerVersion('1.11.0.1', '1.11.0'), isTrue);
  });

  test('chuỗi không đọc được thì không mời cập nhật', () {
    expect(isNewerVersion('latest', '1.11.0'), isFalse);
    expect(isNewerVersion('', '1.11.0'), isFalse);
    expect(isNewerVersion('1.x.0', '1.11.0'), isFalse);
    expect(isNewerVersion('2.0.0', 'dev'), isFalse);
  });

  // Câu trả lời thật của GitHub (rút gọn) cho `GET /repos/<repo>/releases/latest`.
  Map<String, Object?> github({Object? assets}) => {
    'tag_name': 'v1.12.0',
    'name': 'v1.12.0 — Cài đặt đầy đủ',
    'body': '  Có gì mới:\n\n- **Âm báo**\n',
    'assets':
        assets ??
        [
          {'name': 'ghi-chu.txt', 'size': 12},
          {
            'name': 'bow-notify.apk',
            'size': 37581414,
            'digest': 'sha256:${'ab' * 32}',
            'browser_download_url': 'https://noi-khac.example/bow-notify.apk',
          },
        ],
  };

  test('đọc bản phát hành của GitHub: tag, ghi chú, APK kèm mã băm', () {
    final release = AppRelease.fromGitHub(github());
    expect(release.tag, 'v1.12.0');
    expect(release.version, '1.12.0');
    expect(release.notes, 'Có gì mới:\n\n- **Âm báo**');
    expect(release.apkSize, 37581414);
    expect(release.apkSha256, 'ab' * 32);
    expect(release.hasApk, isTrue);
  });

  test(
    'bản phát hành không kèm đúng file APK thì không cập nhật trong app',
    () {
      for (final assets in [
        <Object?>[],
        null,
        'lạ',
        [
          {'name': 'app-khac.apk', 'size': 10},
        ],
        [
          {'name': 'bow-notify.apk', 'size': 0},
        ],
        [
          {'name': 'bow-notify.apk', 'size': '37581414'},
        ],
      ]) {
        final json = github()..['assets'] = assets;
        expect(AppRelease.fromGitHub(json).hasApk, isFalse, reason: '$assets');
      }
    },
  );

  test(
    'mã băm sai khuôn bị bỏ (chỉ còn kiểm kích thước), không làm hỏng cả bản',
    () {
      for (final digest in [
        'md5:abc',
        'sha256:XYZ',
        'sha256:${'AB' * 32}',
        7,
      ]) {
        final release = AppRelease.fromGitHub(
          github(
            assets: [
              {'name': 'bow-notify.apk', 'size': 5, 'digest': digest},
            ],
          ),
        );
        expect(release.apkSize, 5);
        expect(release.apkSha256, isNull, reason: '$digest');
      }
    },
  );

  test('câu trả lời sai khuôn thì ném lỗi', () {
    for (final json in [
      null,
      'chuỗi',
      <Object?>[],
      <String, Object?>{},
      {'tag_name': ''},
      {'tag_name': 12},
      {'tag_name': 'latest'},
      {'tag_name': 'v1.2.3-beta'},
      {'tag_name': '9.9.9+/../../../../ke-khac/repo'},
      {'tag_name': '..'},
    ]) {
      expect(
        () => AppRelease.fromGitHub(json),
        throwsFormatException,
        reason: '$json',
      );
    }
  });

  test('link tải APK ghép từ tag, luôn nằm trong repo phát hành', () {
    expect(
      apkUri('v1.12.0').toString(),
      'https://github.com/$releasesRepo/releases/download/v1.12.0/bow-notify.apk',
    );
    // Tag lạ (vốn đã bị `fromGitHub` từ chối) cũng không trỏ được sang repo khác.
    for (final tag in ['../../../../ke-khac/repo/x?y#z', '..', '.', '']) {
      final odd = apkUri(tag);
      expect(odd.host, 'github.com', reason: tag);
      expect(odd.path, startsWith('/$releasesRepo/releases/'), reason: tag);
      expect(odd.path, endsWith('/bow-notify.apk'), reason: tag);
      expect(odd.hasQuery, isFalse, reason: tag);
      expect(odd.hasFragment, isFalse, reason: tag);
    }
  });
}
