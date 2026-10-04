import 'package:bow_notify/src/models/mirror.dart';
import 'package:bow_notify/src/models/pairing.dart';
import 'package:flutter_test/flutter_test.dart';

final _pairing = Pairing.parse(
  'bowpush://pair?t=bow-${'a' * 32}&p=p1&n=Bow-Mac&k=${'A' * 43}&d=p1-default-rtdb.firebaseio.com',
)!;

void main() {
  test(
    'thanh tab: đọc đủ trường; tab hỏng bị bỏ; thiếu mốc giờ thì không phải thanh tab',
    () {
      final tabs = MachineTabs.fromJson(_pairing, '4000', {
        'at': 1700000000000,
        'active': 't1',
        'tabs': [
          {
            'id': 't1',
            'title': 'A',
            'project': 'p',
            'running': true,
            'pending': 2,
          },
          {'title': 'thiếu id'},
          'rác',
        ],
      })!;
      expect(
        tabs.tabs.map((t) => (t.id, t.title, t.project, t.running, t.pending)),
        [('t1', 'A', 'p', true, 2)],
      );
      expect(MachineTabs.fromJson(_pairing, '4000', {'tabs': []}), isNull);
      expect(MachineTabs.fromJson(_pairing, '4000', 'rác'), isNull);
    },
  );

  test(
    'dữ liệu cũ: trang web im quá 150 giây thì coi là đã đóng / máy đã ngủ',
    () {
      final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final tabs = MachineTabs.fromJson(_pairing, '4000', {
        'at': at.millisecondsSinceEpoch,
        'tabs': [],
      })!;
      expect(
        tabs.stale(at.add(const Duration(seconds: 90))),
        isFalse,
      ); // web báo lại mỗi phút
      expect(tabs.stale(at.add(const Duration(seconds: 151))), isTrue);
    },
  );

  test(
    'dòng chat: loại lạ / thiếu id → null; dòng tool mang tên + tham số + cờ lỗi',
    () {
      final tool = MirrorItem.fromJson({
        'id': 'a',
        'kind': 'tool',
        'text': '',
        'n': 7,
        'tool': {'name': 'Bash', 'summary': 'flutter test', 'error': true},
        'sub': 'soi lỗi',
      })!;
      expect(
        (tool.toolName, tool.toolSummary, tool.toolError, tool.sub, tool.order),
        ('Bash', 'flutter test', true, 'soi lỗi', 7),
      );
      expect(
        MirrorItem.fromJson({'id': 'a', 'kind': 'lạ', 'text': 'x'}),
        isNull,
      );
      expect(MirrorItem.fromJson({'kind': 'agent', 'text': 'x'}), isNull);
    },
  );

  test(
    'quyền gõ: chỉ có khi máy chạy bow ghi `say` trong danh sách việc được làm',
    () {
      MachineTabs tabs(Object? can) => MachineTabs.fromJson(_pairing, '4000', {
        'at': 1,
        'tabs': [],
        'can': ?can,
      })!;
      expect(tabs(['say']).canSay, isTrue);
      expect(tabs([]).canSay, isFalse);
      expect(tabs(null).canSay, isFalse); // server bản cũ không gửi trường này
      expect(tabs('say').canSay, isFalse);
    },
  );
}
