import 'dart:convert';

import 'package:bow_notify/src/models/rtdb_event.dart';
import 'package:flutter_test/flutter_test.dart';

RtdbEvent _ev(String event, String path, Object? data) =>
    (event: event, data: jsonEncode({'path': path, 'data': data}));

void main() {
  test('put ở gốc thay cả nhánh (kể cả về rỗng)', () {
    expect(applyRtdbEvent(null, _ev('put', '/', {'a': 'x', 'b': 'y'})), {
      'a': 'x',
      'b': 'y',
    });
    expect(applyRtdbEvent({'a': 'x'}, _ev('put', '/', 'chuỗi')), 'chuỗi');
    expect(applyRtdbEvent({'a': 'x'}, _ev('put', '/', null)), isNull);
  });

  test(
    'put ở một khoá con: thêm / thay / xoá đúng khoá đó, các khoá khác giữ nguyên',
    () {
      final node = {'a': 'x', 'b': 'y'};
      expect(applyRtdbEvent(node, _ev('put', '/c', 'z')), {
        'a': 'x',
        'b': 'y',
        'c': 'z',
      });
      expect(applyRtdbEvent(node, _ev('put', '/a', 'mới')), {
        'a': 'mới',
        'b': 'y',
      });
      expect(applyRtdbEvent(node, _ev('put', '/a', null)), {'b': 'y'});
      expect(
        applyRtdbEvent({'a': 'x'}, _ev('put', '/a', null)),
        isNull,
      ); // khoá cuối cùng bị xoá ⇒ nhánh rỗng
      expect(node, {'a': 'x', 'b': 'y'}); // không sửa bản cũ tại chỗ
    },
  );

  test(
    'patch ở gốc: trộn nhiều khoá một lượt, null = xoá (đúng lệnh server ghi khi cửa sổ dòng chat trượt)',
    () {
      expect(
        applyRtdbEvent({
          'a': 'x',
          'b': 'y',
        }, _ev('patch', '/', {'a': null, 'b': 'y2', 'c': 'z'})),
        {'b': 'y2', 'c': 'z'},
      );
    },
  );

  test(
    'keep-alive, sự kiện lạ, dữ liệu rác, đường dẫn sâu hơn một cấp → giữ nguyên',
    () {
      final node = {'a': 'x'};
      expect(
        applyRtdbEvent(node, (event: 'keep-alive', data: 'null')),
        same(node),
      );
      expect(applyRtdbEvent(node, (event: 'lạ', data: '{}')), same(node));
      expect(
        applyRtdbEvent(node, (event: 'put', data: 'không phải json')),
        same(node),
      );
      expect(applyRtdbEvent(node, _ev('put', '/a/b', 'x')), same(node));
    },
  );

  test(
    'máy chủ đóng luồng (luật đổi / token hết hạn) → ném để nơi nghe nối lại',
    () {
      for (final event in ['cancel', 'auth_revoked']) {
        expect(
          () => applyRtdbEvent(null, (event: event, data: 'null')),
          throwsA(isA<RtdbStreamClosed>()),
        );
      }
    },
  );
}
