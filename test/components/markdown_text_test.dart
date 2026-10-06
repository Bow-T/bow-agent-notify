import 'package:bow_notify/src/components/markdown_text.dart';
import 'package:bow_notify/src/themes/bow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mọi khối chữ đang hiện. Chữ chọn được nằm trong `SelectableText`, dấu đầu dòng nằm trong `RichText`.
List<InlineSpan> _spans(WidgetTester tester) => [
  for (final w in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  ))
    ?w.textSpan,
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) w.text,
];

String _shown(WidgetTester tester) =>
    _spans(tester).map((span) => span.toPlainText()).join('\n');

/// Có đoạn chữ [text] nào đang hiện với kiểu thoả [test] không.
bool _styled(
  WidgetTester tester,
  String text,
  bool Function(TextStyle style) test,
) {
  var found = false;
  for (final root in _spans(tester)) {
    root.visitChildren((span) {
      if (span is TextSpan &&
          span.text == text &&
          span.style != null &&
          test(span.style!)) {
        found = true;
      }
      return true;
    });
  }
  return found;
}

void main() {
  testWidgets(
    'dựng Markdown: không còn ký hiệu, chữ đậm là đậm, code là chữ đều nét',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: bowTheme(Bow.light),
          home: const Scaffold(
            body: MarkdownText(
              '- **DULB-50, xếp hàng**: chưa bắt đầu\n- dấu `*` chờ designer',
            ),
          ),
        ),
      );
      final shown = _shown(tester);
      expect(shown, contains('DULB-50, xếp hàng'));
      expect(shown, isNot(contains('**')));
      expect(shown, isNot(contains('`')));
      expect(
        _styled(
          tester,
          'DULB-50, xếp hàng',
          (s) => s.fontWeight == FontWeight.w700,
        ),
        isTrue,
      );
      expect(_styled(tester, '*', (s) => s.fontFamily == 'monospace'), isTrue);
    },
  );
}
