import 'package:bow_notify/pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Đúng chuỗi server sinh ở `pairingUri()` (src/core/fcm.ts của repo bow-agent) — đổi khuôn ở một bên là test này đỏ.
  const fromServer =
      'bowpush://pair?t=bow-0123456789abcdef0123456789abcdef&p=bow-notify-demo&n=Tuans-MacBook-Pro';

  test('đọc mã ghép do server sinh', () {
    final pairing = Pairing.parse(fromServer)!;
    expect(pairing.topic, 'bow-0123456789abcdef0123456789abcdef');
    expect(pairing.projectId, 'bow-notify-demo');
    expect(pairing.host, 'Tuans-MacBook-Pro');
  });

  test(
    'tên máy có dấu cách / dấu tiếng Việt vẫn đọc đúng; lưu rồi đọc lại không đổi',
    () {
      final pairing = Pairing.parse(
        '  bowpush://pair?t=bow-${'a' * 32}&p=p1&n=M%C3%A1y+c%E1%BB%A7a+Tu%E1%BA%A5n \n',
      )!;
      expect(pairing.host, 'Máy của Tuấn');
      final again = Pairing.parse(pairing.uri)!;
      expect(
        [again.topic, again.projectId, again.host],
        [pairing.topic, pairing.projectId, pairing.host],
      );
    },
  );

  test('thiếu tên máy vẫn ghép được', () {
    expect(Pairing.parse('bowpush://pair?t=bow-${'0' * 32}&p=p1')!.host, '');
  });

  test('QR lạ / topic sai khuôn / thiếu dự án → null', () {
    for (final raw in [
      '',
      'https://example.com/?t=bow-${'a' * 32}&p=p1',
      'bowpush://other?t=bow-${'a' * 32}&p=p1',
      'bowpush://pair?t=news&p=p1',
      'bowpush://pair?t=bow-${'A' * 32}&p=p1',
      'bowpush://pair?t=bow-${'a' * 31}&p=p1',
      'bowpush://pair?t=bow-${'a' * 32}',
    ]) {
      expect(Pairing.parse(raw), isNull, reason: raw);
    }
  });
}
