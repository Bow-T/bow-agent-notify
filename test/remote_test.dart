import 'package:bow_notify/pairing.dart';
import 'package:bow_notify/remote.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Bản mã do CHÍNH code server sinh (`seal(key, 'card', 'card-1', …)` ở src/core/remoteApproval.ts của bow-agent) với
  // khoá chỉ-dùng-cho-test 0x00…0x1f. Test này đỏ = hai bên không còn mã hoá khớp nhau.
  const key = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';
  const fromServer =
      '6OlvhfyYACjxWAecDScb6CwoQMkhFdy28KHAlOSOo0cxOJZpvVxvLJ_Dt1NhJOGyniuQ3pC2dcOZhd5JxUaVNmQ20gK_UTMwk1UQP5tqRxPNJ8T_pxWJtO65lHxyUc1FsS4ua9EniVYxDHb7dFscHmuoAprYMYjZX77h09hHFUrHhcw3G7hYYR4FmTE5SwRP3H6P5K_dV_zerDD9SnpYFz4E29Yi-wBhiXhd';
  final pairing = Pairing.parse(
    'bowpush://pair?t=bow-${'a' * 32}&p=bow-demo&n=Mac&k=$key&d=bow-demo-default-rtdb.firebaseio.com',
  )!;

  test(
    'mở được thẻ do server mã hoá, đúng nội dung (kể cả chữ có dấu)',
    () async {
      final json = await openCard(pairing, 'card-1', fromServer);
      final card = PendingCard.fromJson(pairing, '4000', 'card-1', json)!;
      expect(card.kind, 'approval');
      expect(card.label, 'DUOCT-3327');
      expect(card.tool, 'Bash');
      expect(card.text, 'git push origin feat/đẩy-thử');
      expect(card.risky, isTrue);
      expect(card.at.millisecondsSinceEpoch, 1700000000000);
    },
  );

  test('sai mã thẻ / sai khoá / bản mã bị sửa / rác → null, không ném', () async {
    expect(await openCard(pairing, 'card-2', fromServer), isNull);
    final other = Pairing.parse(
      'bowpush://pair?t=bow-${'a' * 32}&p=bow-demo&n=Mac&k=${'B' * 43}&d=bow-demo-default-rtdb.firebaseio.com',
    )!;
    expect(await openCard(other, 'card-1', fromServer), isNull);
    final tampered = fromServer.replaceRange(
      40,
      41,
      fromServer[40] == 'A' ? 'B' : 'A',
    );
    expect(await openCard(pairing, 'card-1', tampered), isNull);
    expect(await openCard(pairing, 'card-1', 'không phải bản mã'), isNull);
  });

  test(
    'trả lời: không mở được như một THẺ (khác chiều), mỗi lần mã hoá ra khác nhau',
    () async {
      final reply = await sealReply(pairing, 'card-1', {'allow': true});
      expect(reply.contains('='), isFalse);
      expect(reply.contains('allow'), isFalse);
      expect(await openCard(pairing, 'card-1', reply), isNull);
      expect(await sealReply(pairing, 'card-1', {'allow': true}), isNot(reply));
    },
  );

  test(
    'thẻ sai khuôn (lệch mã thẻ, loại lạ) bị bỏ; câu hỏi đọc đủ lựa chọn',
    () {
      expect(
        PendingCard.fromJson(pairing, '4000', 'x', {
          'id': 'y',
          'kind': 'approval',
        }),
        isNull,
      );
      expect(
        PendingCard.fromJson(pairing, '4000', 'x', {'id': 'x', 'kind': 'lạ'}),
        isNull,
      );
      expect(PendingCard.fromJson(pairing, '4000', 'x', 'chuỗi'), isNull);
      final card = PendingCard.fromJson(pairing, '4000', 'q1', {
        'id': 'q1',
        'kind': 'question',
        'label': 'DUOCT-1',
        'text': 'Chọn nhánh nào?',
        'risky': false,
        'at': 5,
        'questions': [
          {
            'question': 'Chọn nhánh nào?',
            'header': 'Nhánh',
            'multiSelect': true,
            'options': [
              {'label': 'develop', 'description': 'nhánh tích hợp'},
              {'label': 'main', 'description': ''},
            ],
          },
        ],
      })!;
      expect(card.questions.single.multiSelect, isTrue);
      expect(card.questions.single.options.map((o) => o.label), [
        'develop',
        'main',
      ]);
    },
  );
}
