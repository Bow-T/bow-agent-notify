import 'package:bow_notify/src/utils/markdown.dart';
import 'package:flutter_test/flutter_test.dart';

// Đoạn thật user gặp (thẻ trả lời hiện nguyên ký hiệu Markdown).
const _real = '''
- MR !56 chờ bạn merge, nhánh local sẽ xoá ở lượt sau khi đã merge.
- **DULB-50, xếp hàng cập nhật trạng thái khi mất mạng**: chưa bắt đầu, chờ bạn duyệt kế hoạch và hai đề xuất.
- Vẫn mở từ trước: thử trên máy thật; dấu `*` chờ designer; DULB-38 / DULB-103 chờ backend.''';

void main() {
  test(
    'chữ trơn: gỡ ký hiệu đậm / code, gạch đầu dòng thành "• ", KHÔNG đụng dấu * nằm trong code',
    () {
      final plain = markdownToPlain(_real);
      expect(plain, isNot(contains('**')));
      expect(plain, isNot(contains('`')));
      expect(plain.split('\n').length, 3);
      expect(plain, startsWith('• MR !56 chờ bạn merge'));
      expect(
        plain,
        contains(
          '• DULB-50, xếp hàng cập nhật trạng thái khi mất mạng: chưa bắt đầu',
        ),
      );
      expect(
        plain,
        contains('dấu * chờ designer'),
      ); // dấu sao trong `code` là nội dung, phải còn
    },
  );

  test('HTML cho Android: đậm → <b>, code → <tt>, mỗi mục một dòng', () {
    final html = markdownToAndroidHtml(_real);
    expect(
      html,
      contains(
        '• <b>DULB-50, xếp hàng cập nhật trạng thái khi mất mạng</b>: chưa bắt đầu',
      ),
    );
    expect(html, contains('dấu <tt>*</tt> chờ designer'));
    expect('<br>'.allMatches(html).length, 2);
    expect(html, isNot(contains('**')));
  });

  test('HTML: ký tự < > & trong lời agent được thoát — không thành thẻ', () {
    final html = markdownToAndroidHtml(
      'So sánh `a < b && b > c` rồi <script>x</script>',
    );
    expect(html, contains('<tt>a &lt; b &amp;&amp; b &gt; c</tt>'));
    expect(html, isNot(contains('<script>')));
  });

  test('tiêu đề, nghiêng, gạch bỏ, link, danh sách số + danh sách con', () {
    const text = '''
## Kết quả

Đã *xong* ~~cũ~~ — xem [MR 56](https://x.test/56).

1. Bước một
2. Bước hai
   - ý con''';
    expect(
      markdownToAndroidHtml(text),
      '<b>Kết quả</b><br>Đã <i>xong</i> <s>cũ</s> — xem MR 56.<br>1. Bước một<br>2. Bước hai<br>&nbsp;&nbsp;&nbsp;• ý con',
    );
    expect(
      markdownToPlain(text),
      'Kết quả\nĐã xong cũ — xem MR 56.\n1. Bước một\n2. Bước hai\n   • ý con',
    );
  });

  test('khối code giữ nguyên từng dòng (kể cả ký hiệu Markdown bên trong)', () {
    const text = 'Chạy:\n\n```sh\ngit add **/*.dart\nnpm test\n```';
    expect(markdownToPlain(text), 'Chạy:\ngit add **/*.dart\nnpm test');
    expect(
      markdownToAndroidHtml(text),
      'Chạy:<br><tt>git add **/*.dart<br>npm test</tt>',
    );
  });

  test('bảng: mỗi hàng một dòng, các ô cách nhau bằng " · "', () {
    const text =
        '| Ticket | Trạng thái |\n| --- | --- |\n| DULB-46 | **xong** |';
    expect(markdownToPlain(text), 'Ticket · Trạng thái\nDULB-46 · xong');
  });

  test(
    'đoạn bị cắt GIỮA khối code (hàng rào mở đã mất) → thêm lại hàng rào, văn xuôi phía sau không thành code',
    () {
      const tail = '…  return x;\n}\n```\n\nĐã sửa **xong**.';
      expect(prepareMarkdown(tail), startsWith('…\n\n```\n'));
      expect(markdownToAndroidHtml(tail), endsWith('Đã sửa <b>xong</b>.'));
      expect(
        prepareMarkdown('```\na\n```\nb'),
        '```\na\n```\nb',
      ); // đủ cặp thì giữ nguyên
    },
  );

  test(
    'dấu "…" server gắn ở chỗ cắt được tách ra dòng riêng — dính vào thì mục đầu không còn là gạch đầu dòng',
    () {
      expect(
        markdownToPlain('…- mục một\n- mục hai'),
        '…\n• mục một\n• mục hai',
      );
      expect(
        markdownToAndroidHtml('…## Kết quả\nxong'),
        '…<br><b>Kết quả</b><br>xong',
      );
    },
  );

  test(
    'markdownTail: lấy phần CUỐI theo dòng (lời mời trả lời nằm ở đó), không tốn dòng cho dấu "…"',
    () {
      const text =
          '- mục một rất dài dòng\n- mục hai\n\nTiếp theo: trả lời **"duyệt"** để làm tiếp.';
      expect(markdownTail(text, 1000), text); // vừa thì giữ nguyên
      expect(
        markdownTail('…$text', 1000),
        text,
      ); // dấu "…" server gắn ở đầu cũng gỡ
      expect(
        markdownTail(text, 50),
        'Tiếp theo: trả lời **"duyệt"** để làm tiếp.',
      );
      expect(
        markdownToPlain(markdownTail(text, 75)),
        '• mục hai\nTiếp theo: trả lời "duyệt" để làm tiếp.',
      );
      // Một dòng duy nhất quá dài: giữ phần cuối của nó.
      expect(markdownTail('${'a' * 50} hết', 10), '…${'a' * 6} hết');
      expect(markdownTail('', 10), '');
    },
  );

  test(
    'markdownTail cắt vào giữa khối code → thêm lại hàng rào mở, phần sau không thành code',
    () {
      const text =
          'Mở đầu rất dài dòng không vừa.\n```\nlệnh một\nlệnh hai\n```\nĐã **xong**.';
      expect(
        markdownToAndroidHtml(markdownTail(text, 30)),
        '<tt>lệnh hai</tt><br>Đã <b>xong</b>.',
      );
    },
  );

  test(
    'chữ trơn không có Markdown đi qua nguyên vẹn; chuỗi rỗng không lỗi',
    () {
      expect(
        markdownToPlain('Xong. Tiếp theo: chạy test.'),
        'Xong. Tiếp theo: chạy test.',
      );
      expect(markdownToPlain(''), '');
      expect(markdownToAndroidHtml(''), '');
    },
  );
}
