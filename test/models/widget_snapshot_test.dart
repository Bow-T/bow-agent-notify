import 'package:bow_notify/src/models/pairing.dart';
import 'package:bow_notify/src/models/pending_card.dart';
import 'package:bow_notify/src/models/widget_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

final _pairing = Pairing.parse(
  'bowpush://pair?t=bow-${'a' * 32}&p=p1&n=Bow-Mac&k=${'A' * 43}&d=p1-default-rtdb.firebaseio.com',
)!;

PendingCard _card(String id, int at, Map<String, Object?> json) =>
    PendingCard.fromJson(_pairing, '4000', id, {
      'id': id,
      'label': 'DULB-46',
      'text': 'git push',
      'at': at,
      ...json,
    })!;

final _now = DateTime(2026, 10, 4, 8, 42);

Map<String, String> _snap(
  List<PendingCard> cards, {
  int machines = 1,
  bool busy = false,
}) => widgetSnapshot(cards: cards, machines: machines, now: _now, busy: busy);

void main() {
  test(
    'chọn thẻ: thẻ đang CHẶN agent (duyệt / câu hỏi) đứng trên lời mời trả lời; cùng nhóm thì cũ nhất trước',
    () {
      final reply = _card('r', 1, {
        'kind': 'reply',
        'options': ['tiếp'],
      });
      final late = _card('late', 30, {'kind': 'approval'});
      final early = _card('early', 20, {'kind': 'approval'});
      expect(widgetCard([reply, late, early])!.id, 'early');
      expect(widgetCard([reply])!.id, 'r');
      expect(widgetCard([]), isNull);
    },
  );

  test(
    'thẻ duyệt thường: hai nút gửi thẳng, mã thẻ nằm trong `w_ref`, không cờ rủi ro',
    () {
      final s = _snap([
        _card('c 1', 5, {'kind': 'approval', 'risky': false}),
      ]);
      expect(s['w_card'], '1');
      expect(s['w_kind'], 'approval');
      expect(s['w_label'], 'DULB-46');
      expect(s['w_text'], 'git push');
      expect(s['w_host'], 'Bow-Mac');
      expect(s['w_risky'], '');
      expect(
        s['w_ref'],
        't=bow-${'a' * 32}&p=4000&i=c+1',
      ); // mã thẻ được mã hoá cho đường dẫn
      expect((s['w_a0_id'], s['w_a0_opens']), ('allow', ''));
      expect((s['w_a1_id'], s['w_a1_opens']), ('deny', ''));
      expect(s['w_a2_title'], '');
      expect(s['w_count'], '1');
      expect(s['w_updated_ms'], '${_now.millisecondsSinceEpoch}');
    },
  );

  test(
    'thẻ RỦI RO: nút đầu chỉ MỞ APP (không có nút cho phép trên widget), vẫn từ chối được',
    () {
      final s = _snap([
        _card('c1', 5, {'kind': 'approval', 'risky': true}),
      ]);
      expect(s['w_risky'], '1');
      expect((s['w_a0_id'], s['w_a0_opens']), ('open', '1'));
      expect((s['w_a1_id'], s['w_a1_opens']), ('deny', ''));
      expect([
        s['w_a0_id'],
        s['w_a1_id'],
        s['w_a2_id'],
      ], isNot(contains('allow')));
    },
  );

  test('lời mời trả lời: tối đa ba câu thành nút', () {
    final s = _snap([
      _card('r', 5, {
        'kind': 'reply',
        'options': ['push', 'tiếp', 'commit/push', 'kiểm tra'],
      }),
    ]);
    expect(
      [s['w_a0_title'], s['w_a1_title'], s['w_a2_title']],
      ['push', 'tiếp', 'commit/push'],
    );
    expect(
      [s['w_a0_id'], s['w_a1_id'], s['w_a2_id']],
      ['say:0', 'say:1', 'say:2'],
    );
  });

  test(
    'không có thẻ: mọi khoá của thẻ và nút đều rỗng (nút cũ không được sót lại trên widget)',
    () {
      final s = _snap([]);
      expect(s['w_card'], '');
      expect(s['w_badge'], '');
      expect(s['w_ref'], '');
      for (final key in s.keys.where((k) => k.startsWith('w_a'))) {
        expect(s[key], '', reason: key);
      }
      expect(s['w_empty_icon'], 'done');
      expect(s['w_status_icon'], 'logo');
    },
  );

  test('chưa ghép máy nào: widget mời mở app, không báo "không có gì chờ"', () {
    final s = _snap([], machines: 0);
    expect(s['w_machines'], '0');
    expect(s['w_empty_icon'], 'logo');
    expect(s['w_empty_title'], isNot(_snap([])['w_empty_title']));
  });

  test(
    'không còn gì chờ thì hiện việc gần nhất kèm giờ; lượt lỗi thì icon lỗi',
    () {
      final s = widgetSnapshot(
        cards: const [],
        machines: 1,
        now: _now,
        last: (
          kind: 'fatal',
          title: 'Bow · failed',
          body: 'DULB-46',
          at: DateTime(2026, 10, 4, 8, 5),
        ),
      );
      expect(s['w_empty_icon'], 'fatal');
      expect(s['w_empty_sub'], 'Bow · failed · DULB-46 · 08:05');
    },
  );

  test(
    'đang gửi quyết định: cờ `w_busy` bật (widget thay hàng nút bằng "Đang gửi…")',
    () {
      final card = _card('c1', 5, {'kind': 'approval'});
      expect(_snap([card])['w_busy'], '');
      expect(_snap([card], busy: true)['w_busy'], '1');
    },
  );

  test(
    '"việc gần nhất" chỉ tính lượt đã xong / lỗi — thông báo xin duyệt cũ không được nằm lại trên widget',
    () {
      expect(
        [
          for (final kind in ['done', 'fatal']) isWidgetEvent(kind),
        ],
        [true, true],
      );
      expect([
        for (final kind in ['approval', 'question', 'test', ''])
          isWidgetEvent(kind),
      ], everyElement(isFalse));
    },
  );
}
