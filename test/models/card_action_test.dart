import 'package:bow_notify/src/models/card_action.dart';
import 'package:bow_notify/src/models/card_ref.dart';
import 'package:bow_notify/src/models/pairing.dart';
import 'package:bow_notify/src/models/pending_card.dart';
import 'package:flutter_test/flutter_test.dart';

final _pairing = Pairing.parse(
  'bowpush://pair?t=bow-${'a' * 32}&p=p1&n=Mac&k=${'A' * 43}&d=p1-default-rtdb.firebaseio.com',
)!;

PendingCard _card(Map<String, Object?> json) => PendingCard.fromJson(
  _pairing,
  '4000',
  'c1',
  {'id': 'c1', 'label': 'DUOCT-1', 'text': 'x', 'at': 1, ...json},
)!;

Map<String, Object?> _question({
  bool multi = false,
  int options = 2,
  int questions = 1,
}) => {
  'kind': 'question',
  'questions': [
    for (var q = 0; q < questions; q++)
      {
        'question': 'Câu $q?',
        'header': 'H',
        'multiSelect': multi,
        'options': [
          for (var i = 0; i < options; i++)
            {'label': 'Lựa chọn $i', 'description': ''},
        ],
      },
  ],
};

void main() {
  test('mã gắn theo thông báo: mã hoá rồi đọc lại không đổi; rác → null', () {
    const ref = (topic: 'bow-x', port: '4000', id: 'c1', tag: 's-1');
    expect(decodeRef(encodeRef(ref)), ref);
    for (final junk in [
      null,
      '',
      'abc',
      '[]',
      '{"t":"a"}',
      '{"t":1,"p":"4000","i":"c1","g":"s"}',
    ]) {
      expect(decodeRef(junk), isNull, reason: '$junk');
    }
  });

  test('sổ thông báo có nút: ghi rồi đọc lại không đổi; rác → rỗng', () {
    final ShownCards shown = {
      's-1': (id: 'c1', at: 100),
      'admin-s2': (id: 'r7', at: 250),
    };
    expect(decodeShown(encodeShown(shown)), shown);
    for (final junk in [
      null,
      '',
      '[]',
      '{"s":1}',
      '{"s":{"i":1,"a":2}}',
      '{"s":{"i":"c"}}',
    ]) {
      expect(decodeShown(junk), isEmpty, reason: '$junk');
    }
  });

  test(
    'gỡ thông báo có nút: chỉ của thẻ không còn chờ, và chỉ thông báo hiện TRƯỚC lúc đọc danh sách',
    () {
      final ShownCards shown = {
        'done': (id: 'c1', at: 100), // thẻ đã xử lý → gỡ
        'live': (id: 'c2', at: 100), // thẻ còn chờ → giữ
        'new': (
          id: 'c3',
          at: 500,
        ), // hiện sau lúc đọc: lần đọc này chưa kịp thấy thẻ → giữ
      };
      expect(staleTags(shown, {'c2'}, 300), ['done']);
      expect(staleTags(shown, {'c2'}, 600), ['done', 'new']);
      expect(staleTags({}, {'c2'}, 600), isEmpty);
    },
  );

  test('thẻ duyệt thường: nút Cho phép + Từ chối, gửi đúng quyết định', () {
    final card = _card({'kind': 'approval', 'risky': false});
    expect(cardActions(card).map((a) => (a.id, a.opensApp)), [
      ('allow', false),
      ('deny', false),
    ]);
    expect(replyForAction(card, 'allow'), {'allow': true});
    expect(replyForAction(card, 'deny'), {'allow': false});
    expect(replyForAction(card, 'opt:0'), isNull);
  });

  test(
    'thẻ RỦI RO: không có nút Cho phép, và mã nút "allow" giả cũng không gửi được gì',
    () {
      final card = _card({'kind': 'approval', 'risky': true});
      expect(cardActions(card).map((a) => (a.id, a.opensApp)), [
        ('open', true),
        ('deny', false),
      ]);
      expect(replyForAction(card, 'allow'), isNull);
      expect(replyForAction(card, 'deny'), {'allow': false});
      expect(replyForAction(card, 'open'), isNull);
    },
  );

  test(
    'lời mời trả lời: mỗi câu một nút (tối đa ba), gửi lại ĐÚNG câu đã mời',
    () {
      final card = _card({
        'kind': 'reply',
        'options': ['push', 'tiếp', 'commit/push', 'kiểm tra'],
      });
      expect(cardActions(card).map((a) => (a.id, a.title, a.opensApp)), [
        ('say:0', 'push', false),
        ('say:1', 'tiếp', false),
        ('say:2', 'commit/push', false),
      ]);
      expect(replyForAction(card, 'say:2'), {'say': 'commit/push'});
      expect(replyForAction(card, 'say:3'), {'say': 'kiểm tra'});
      for (final bad in [
        'say:4',
        'say:-1',
        'say:x',
        'allow',
        'deny',
        'opt:0',
      ]) {
        expect(replyForAction(card, bad), isNull, reason: bad);
      }
    },
  );

  test(
    'thẻ `reply` không có câu nào thì không phải thẻ; thẻ duyệt không nhận nút của lời mời',
    () {
      expect(
        PendingCard.fromJson(_pairing, '4000', 'c1', {
          'id': 'c1',
          'kind': 'reply',
          'label': 'x',
          'text': 'Xong.',
          'at': 1,
          'options': <String>[],
        }),
        isNull,
      );
      final approval = _card({'kind': 'approval', 'risky': false});
      expect(replyForAction(approval, 'say:0'), isNull);
    },
  );

  test(
    'câu hỏi gọn (một câu, chọn một, tối đa ba lựa chọn): mỗi lựa chọn một nút',
    () {
      final card = _card(_question(options: 3));
      expect(cardActions(card).map((a) => (a.id, a.title)), [
        ('opt:0', 'Lựa chọn 0'),
        ('opt:1', 'Lựa chọn 1'),
        ('opt:2', 'Lựa chọn 2'),
      ]);
      expect(replyForAction(card, 'opt:1'), {
        'answers': {'Câu 0?': 'Lựa chọn 1'},
      });
      for (final bad in ['opt:3', 'opt:-1', 'opt:x', 'allow', 'deny']) {
        expect(replyForAction(card, bad), isNull, reason: bad);
      }
    },
  );

  test(
    'câu hỏi không gọn (chọn nhiều / bốn lựa chọn / hai câu): chỉ có nút mở app, không gửi được từ thông báo',
    () {
      for (final json in [
        _question(multi: true),
        _question(options: 4),
        _question(questions: 2),
      ]) {
        final card = _card(json);
        expect(cardActions(card).map((a) => (a.id, a.opensApp)), [
          ('open', true),
        ]);
        expect(replyForAction(card, 'opt:0'), isNull);
      }
    },
  );
}
