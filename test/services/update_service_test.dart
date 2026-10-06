import 'dart:io';

import 'package:bow_notify/src/services/update_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

// Bước ghi file APK tải về: chỉ để lại file khi nó đúng là bản phát hành (đủ kích thước + khớp mã băm).

Future<String> _sha256(List<int> bytes) async => (await Sha256().hash(
  bytes,
)).bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  late Directory dir;
  late File target;
  final apk = List<int>.generate(5000, (i) => i % 251);

  /// Thân câu trả lời HTTP: [bytes] chia thành từng mẩu như khi tải qua mạng.
  Stream<List<int>> body(List<int> bytes, {int chunk = 1024}) async* {
    for (var i = 0; i < bytes.length; i += chunk) {
      yield bytes.sublist(i, (i + chunk).clamp(0, bytes.length));
    }
  }

  List<String> files() => [
    for (final entry in dir.listSync()) entry.uri.pathSegments.last,
  ];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('bow-update-test');
    target = File('${dir.path}/bow-notify-9.9.9.apk');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('đủ kích thước + khớp mã băm: file nằm đúng tên, báo tiến độ tăng '
      'dần, không để lại file tạm', () async {
    final seen = <int>[];
    await saveVerified(
      body(apk),
      target,
      size: apk.length,
      sha256: await _sha256(apk),
      onProgress: seen.add,
    );
    expect(target.readAsBytesSync(), apk);
    expect(seen, [1024, 2048, 3072, 4096, 5000]);
    expect(files(), ['bow-notify-9.9.9.apk']);
  });

  test('bản phát hành cũ không có mã băm: chỉ kiểm kích thước', () async {
    await saveVerified(body(apk), target, size: apk.length);
    expect(target.readAsBytesSync(), apk);
  });

  test(
    'sai mã băm (nội dung bị đổi, kích thước vẫn đúng): không để lại gì',
    () async {
      final tampered = [...apk]..[100] ^= 1;
      await expectLater(
        saveVerified(
          body(tampered),
          target,
          size: apk.length,
          sha256: await _sha256(apk),
        ),
        throwsFormatException,
      );
      expect(files(), isEmpty);
    },
  );

  test(
    'tải thiếu (mạng đứt giữa chừng nhưng luồng đóng êm): không để lại gì',
    () async {
      await expectLater(
        saveVerified(body(apk.sublist(0, 3000)), target, size: apk.length),
        throwsFormatException,
      );
      expect(files(), isEmpty);
    },
  );

  test(
    'nguồn gửi NHIỀU hơn kích thước đã khai: dừng ngay, không ghi tiếp',
    () async {
      var sent = 0;
      Stream<List<int>> endless() async* {
        while (true) {
          sent++;
          yield List<int>.filled(1024, 7);
        }
      }

      await expectLater(
        saveVerified(endless(), target, size: 3000),
        throwsFormatException,
      );
      expect(sent, lessThan(10));
      expect(files(), isEmpty);
    },
  );

  test('mạng đứt giữa chừng: lỗi đó đi lên, phần đã tải được GIỮ; lần sau tải '
      'tiếp phần còn lại và mã băm vẫn tính trên cả file', () async {
    Stream<List<int>> broken() async* {
      yield apk.sublist(0, 1000);
      throw const SocketException('mất mạng');
    }

    final sha = await _sha256(apk);
    await expectLater(
      saveVerified(broken(), target, size: apk.length, sha256: sha),
      throwsA(isA<SocketException>()),
    );
    expect(files(), ['bow-notify-9.9.9.apk.part']);
    expect(partOf(target).lengthSync(), 1000);

    final seen = <int>[];
    await saveVerified(
      body(apk.sublist(1000)),
      target,
      size: apk.length,
      sha256: sha,
      resumeFrom: 1000,
      onProgress: seen.add,
    );
    expect(target.readAsBytesSync(), apk);
    expect(seen.first, 2024); // tiến độ đi tiếp từ chỗ đã có, không về 0
    expect(seen.last, 5000);
    expect(files(), ['bow-notify-9.9.9.apk']);
  });

  test('máy chủ không chịu tải tiếp (trả cả file): ghi đè phần dở, không nối '
      'thêm vào', () async {
    partOf(target).writeAsBytesSync(List<int>.filled(1000, 9));
    await saveVerified(
      body(apk),
      target,
      size: apk.length,
      sha256: await _sha256(apk),
    );
    expect(target.readAsBytesSync(), apk);
  });

  test('phần tải dở bị đổi / không còn nguyên: tải tiếp xong là lệch mã băm → '
      'xoá sạch để lần sau tải lại từ đầu', () async {
    final sha = await _sha256(apk);
    partOf(target).writeAsBytesSync([...apk.sublist(0, 1000)]..[10] ^= 1);
    await expectLater(
      saveVerified(
        body(apk.sublist(1000)),
        target,
        size: apk.length,
        sha256: sha,
        resumeFrom: 1000,
      ),
      throwsFormatException,
    );
    expect(files(), isEmpty);

    // File dở ngắn hơn chỗ định tải tiếp.
    partOf(target).writeAsBytesSync(apk.sublist(0, 500));
    await expectLater(
      saveVerified(
        body(apk.sublist(1000)),
        target,
        size: apk.length,
        sha256: sha,
        resumeFrom: 1000,
      ),
      throwsFormatException,
    );
    expect(files(), isEmpty);
  });
}
