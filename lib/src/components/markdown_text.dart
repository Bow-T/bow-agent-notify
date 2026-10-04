import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../themes/bow_theme.dart';
import '../utils/markdown.dart';

/// Lời agent (Markdown) dựng theo bảng màu của app: đậm / nghiêng, danh sách, code, bảng. Chọn + chép được.
/// Link chỉ tô màu, không mở — app này không mở trình duyệt thay người dùng.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final body = TextStyle(color: c.ink, fontSize: 14, height: 1.4);
    final bold = body.copyWith(fontWeight: FontWeight.w700);
    final mono = body.copyWith(
      fontSize: 12.5,
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Courier'],
      backgroundColor: c.well,
    );
    return MarkdownBody(
      data: prepareMarkdown(data),
      selectable: true,
      // Xuống dòng trong một đoạn là xuống dòng thật: lời agent hay dùng nó để tách ý.
      softLineBreak: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: body,
        strong: bold,
        em: body.copyWith(fontStyle: FontStyle.italic),
        del: body.copyWith(decoration: TextDecoration.lineThrough),
        a: body.copyWith(color: c.accent),
        h1: bold.copyWith(fontSize: 17),
        h2: bold.copyWith(fontSize: 16),
        h3: bold.copyWith(fontSize: 15),
        h4: bold,
        h5: bold,
        h6: bold,
        listBullet: body.copyWith(color: c.muted),
        listIndent: 20,
        blockSpacing: 8,
        code: mono,
        codeblockPadding: const EdgeInsets.all(10),
        codeblockDecoration: BoxDecoration(
          color: c.well,
          borderRadius: BorderRadius.circular(10),
        ),
        blockquote: body.copyWith(color: c.muted),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: c.hairline, width: 3)),
        ),
        tableHead: bold.copyWith(fontSize: 13),
        tableBody: body.copyWith(fontSize: 13),
        tableBorder: TableBorder.all(color: c.hairline),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.hairline)),
        ),
      ),
    );
  }
}
