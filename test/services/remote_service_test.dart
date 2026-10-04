import 'package:bow_notify/src/models/mirror.dart';
import 'package:bow_notify/src/models/pairing.dart';
import 'package:bow_notify/src/models/pending_card.dart';
import 'package:bow_notify/src/services/remote_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const remote = RemoteService();
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
      final json = await remote.openCard(pairing, 'card-1', fromServer);
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
    expect(await remote.openCard(pairing, 'card-2', fromServer), isNull);
    final other = Pairing.parse(
      'bowpush://pair?t=bow-${'a' * 32}&p=bow-demo&n=Mac&k=${'B' * 43}&d=bow-demo-default-rtdb.firebaseio.com',
    )!;
    expect(await remote.openCard(other, 'card-1', fromServer), isNull);
    final tampered = fromServer.replaceRange(
      40,
      41,
      fromServer[40] == 'A' ? 'B' : 'A',
    );
    expect(await remote.openCard(pairing, 'card-1', tampered), isNull);
    expect(
      await remote.openCard(pairing, 'card-1', 'không phải bản mã'),
      isNull,
    );
  });

  test(
    'trả lời: không mở được như một THẺ (khác chiều), mỗi lần mã hoá ra khác nhau',
    () async {
      final reply = await remote.sealReply(pairing, 'card-1', {'allow': true});
      expect(reply.contains('='), isFalse);
      expect(reply.contains('allow'), isFalse);
      expect(await remote.openCard(pairing, 'card-1', reply), isNull);
      expect(
        await remote.sealReply(pairing, 'card-1', {'allow': true}),
        isNot(reply),
      );
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

  // Bản mã của nhánh "tab trên máy", do CHÍNH code server sinh (`seal(key, 'mirror', …)` ở bow-agent) với cùng khoá test.
  const mirrorItem =
      'sC154R8Sh0VBLWushGvXtZ27gbFI9PGmDcpwzdE9VP3a15_4sIukF4fOQJt9Gwwo_hn9-EMtLAO_LN9JxiVLgeOKZ5cNCgdLIZZr_6mcmLj8eTz9-IWU6iRlZMXmCXF2Q9DZiHACMSx6VWe3W9ztjbOfJ1SU0YZm62Q6fjI9pHJ2dXki8TcCg6mQWH66achORdK08YreWnF0FA';
  const mirrorTabs =
      'odclsIxJf5ker2BeZgh7P_a75CQtRcvHMF5FA7hNtio2A32Yt1NtqH7mijfmT8XkK8DLBXiKISqKhnzwwBcW03QS_T_pE4VWblUOnT4nBm84kndaw90tdGePfMJix5EH7N80m_y7CXKFOAQMyzdWSCeu3KHbuHw6a7nS6FnhthUdc7DcYMQJN9bPhDAFzic6Kte0V20bbBKTHhDAJuHf64bq7rquzsvexXNTNjc';

  test(
    'mở được dòng chat + danh sách tab do server mã hoá cho "tab trên máy"',
    () async {
      final item = MirrorItem.fromJson(
        await remote.openMirror(pairing, 't1/1700000000000-3', mirrorItem),
      )!;
      expect(item.kind, 'agent');
      expect(item.text, 'Đã sửa **xong** lỗi đếm.');
      expect(item.sub, 'soi lỗi');
      expect(item.order, 12);
      expect(item.at!.millisecondsSinceEpoch, 1700000000000);

      final tabs = MachineTabs.fromJson(
        pairing,
        '4000',
        await remote.openMirror(pairing, 'tabs', mirrorTabs),
      )!;
      expect(tabs.active, 't1');
      final tab = tabs.tabs.single;
      expect(
        (tab.title, tab.project, tab.running, tab.pending),
        ('DULB-46 đếm số món', 'labuse-delivery', true, 1),
      );
    },
  );

  test(
    'dòng của tab này không mở được dưới tên tab khác; bản mã "tab trên máy" không mở ra thành thẻ duyệt',
    () async {
      expect(
        await remote.openMirror(pairing, 't2/1700000000000-3', mirrorItem),
        isNull,
      );
      expect(
        await remote.openCard(pairing, 't1/1700000000000-3', mirrorItem),
        isNull,
      );
      expect(
        await remote.openMirror(pairing, 'card-1', fromServer),
        isNull,
      ); // và ngược lại
    },
  );
}
