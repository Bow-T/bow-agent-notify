import 'package:markdown/markdown.dart' as md;

/// Lời agent là Markdown. Trong app nó được dựng bằng `MarkdownText` (components/markdown_text.dart); file này lo hai
/// nơi KHÔNG dựng được widget Flutter — thông báo và widget màn hình chính của Android — bằng cách đổi sang:
///  - HTML rút gọn mà `Html.fromHtml` của Android hiểu (đậm, nghiêng, chữ đều nét, xuống dòng, gạch đầu dòng);
///  - chữ trơn đã gỡ ký hiệu (dòng thu gọn của thông báo, nơi không nhận định dạng).
/// Đọc bằng `package:markdown` (cùng bộ đọc với phần dựng trong app) chứ không tự dò ký hiệu bằng regex: `**`, `_`,
/// dấu `` ` `` nằm trong code hay trong tên file mà gỡ bừa là hỏng nội dung.

final _fence = RegExp(r'^\s*(```|~~~)', multiLine: true);

/// Chuẩn bị đoạn Markdown server gửi trước khi dựng. Server gửi ĐOẠN CUỐI của câu trả lời, cắt từ đầu một dòng và
/// đánh dấu chỗ cắt bằng "…" dính liền dòng đầu, nên:
///  - tách "…" ra dòng riêng — dính vào thì "…- mục" không còn là một mục danh sách, "…## Tiêu đề" không còn là tiêu đề;
///  - đoạn có thể bắt đầu GIỮA một khối code: số hàng rào lẻ nghĩa là hàng rào mở đã bị cắt mất. Thêm lại nó, không thì
///    phần văn xuôi phía sau bị dựng ngược thành code.
String prepareMarkdown(String text) {
  final cut = text.startsWith('…');
  final body = cut ? text.substring(1).trimLeft() : text;
  final openFence = _fence.allMatches(body).length.isOdd ? '```\n' : '';
  return '${cut ? '…\n\n' : ''}$openFence$body';
}

/// Phần CUỐI của một đoạn Markdown, vừa trong [maxChars], cắt theo DÒNG. Thông báo và widget chỉ hiện được vài dòng,
/// mà lời mời trả lời ("trả lời "duyệt" để…") luôn nằm ở cuối — hiện phần đầu là mất đúng thứ cần đọc.
///
/// Không đánh dấu chỗ cắt bằng "…": ở hai nơi đó ai cũng hiểu đây là trích đoạn, mà một dòng "…" là mất một trong
/// vài dòng ít ỏi. (Dấu "…" server gắn sẵn ở đầu cũng được gỡ vì cùng lý do.)
String markdownTail(String text, int maxChars) {
  final body = (text.startsWith('…') ? text.substring(1) : text).trim();
  final lines = body.split('\n');
  var from = lines.length;
  var used = 0;
  while (from > 0 && used + lines[from - 1].length + 1 <= maxChars) {
    used += lines[--from].length + 1;
  }
  // Một dòng duy nhất mà đã quá dài: giữ phần cuối của chính dòng đó.
  if (from == lines.length) {
    return '…${lines.last.substring(lines.last.length - maxChars)}';
  }
  final tail = lines.sublist(from).join('\n').trimLeft();
  // Cắt vào giữa một khối code thì thêm lại hàng rào mở (như `prepareMarkdown`).
  return _fence.allMatches(tail).length.isOdd ? '```\n$tail' : tail;
}

List<md.Node> _parse(String text) => md.Document(
  extensionSet: md.ExtensionSet.gitHubFlavored,
  encodeHtml: false,
).parse(prepareMarkdown(text));

const _blocks = {
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'pre',
  'blockquote',
  'table',
  'hr',
};

bool _isBlock(md.Node node) => node is md.Element && _blocks.contains(node.tag);

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Dựng một danh sách nút thành chuỗi. [html] = HTML rút gọn cho Android; không thì chữ trơn.
class _Writer {
  _Writer({required this.html});

  final bool html;

  String get _br => html ? '<br>' : '\n';

  String _text(String text) => html ? _escape(text) : text;

  String _wrap(String tag, String inner) =>
      html && inner.isNotEmpty ? '<$tag>$inner</$tag>' : inner;

  /// Các khối nối nhau bằng MỘT lần xuống dòng — màn hình thông báo / widget chật, không để dòng trống giữa các khối.
  String blocks(List<md.Node> nodes) => [
    for (final node in nodes) block(node),
  ].where((part) => part.isNotEmpty).join(_br);

  String block(md.Node node) {
    if (node is! md.Element) return _text(node.textContent.trim());
    final children = node.children ?? const <md.Node>[];
    switch (node.tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        return _wrap('b', inline(children));
      case 'ul' || 'ol':
        final start = int.tryParse(node.attributes['start'] ?? '') ?? 1;
        return [
          for (final (i, item) in children.whereType<md.Element>().indexed)
            _item(item, node.tag == 'ol' ? '${start + i}. ' : '• '),
        ].join(_br);
      case 'pre':
        final code = node.textContent.trimRight();
        return _wrap('tt', _text(code).replaceAll('\n', _br));
      case 'blockquote':
        return _wrap('i', blocks(children));
      case 'table':
        // Bảng không dựng được ở hai nơi này: mỗi hàng một dòng, các ô cách nhau bằng " · ".
        return [
          for (final row in _rows(node))
            [
              for (final cell in row.children ?? const <md.Node>[])
                inline(cell is md.Element ? cell.children ?? const [] : [cell]),
            ].join(' · '),
        ].join(_br);
      case 'hr':
        return '———';
      default:
        return inline(children);
    }
  }

  Iterable<md.Element> _rows(md.Element table) sync* {
    for (final part
        in table.children?.whereType<md.Element>() ?? const <md.Element>[]) {
      if (part.tag == 'tr') {
        yield part;
      } else {
        yield* _rows(part);
      }
    }
  }

  /// Một mục của danh sách: chữ của nó, rồi danh sách con (nếu có) thụt vào ở các dòng dưới.
  String _item(md.Element item, String bullet) {
    final children = item.children ?? const <md.Node>[];
    final own = <md.Node>[];
    final nested = <String>[];
    for (final child in children) {
      if (child is md.Element && (child.tag == 'ul' || child.tag == 'ol')) {
        nested.add(block(child));
      } else if (child is md.Element && child.tag == 'p') {
        if (own.isNotEmpty) own.add(md.Text(' '));
        own.addAll(child.children ?? const []);
      } else if (_isBlock(child)) {
        nested.add(block(child));
      } else {
        own.add(child);
      }
    }
    final indent = html ? '&nbsp;&nbsp;&nbsp;' : '   ';
    return [
      '$bullet${inline(own).trim()}',
      for (final part in nested)
        for (final line in part.split(_br)) '$indent$line',
    ].join(_br);
  }

  String inline(List<md.Node> nodes) =>
      [for (final node in nodes) _inline(node)].join();

  String _inline(md.Node node) {
    if (node is! md.Element) {
      // Xuống dòng trong một đoạn được giữ (lời agent hay dùng nó để tách ý).
      return _text(node.textContent).replaceAll('\n', _br);
    }
    final inner = inline(node.children ?? const []);
    return switch (node.tag) {
      'strong' => _wrap('b', inner),
      'em' => _wrap('i', inner),
      'code' => _wrap('tt', _text(node.textContent)),
      'del' => _wrap('s', inner),
      'br' => _br,
      'img' => _text(node.attributes['alt'] ?? ''),
      _ =>
        inner, // link: chỉ giữ chữ — thông báo / widget không bấm được vào link
    };
  }
}

/// Markdown → HTML rút gọn cho `Html.fromHtml` của Android (thông báo, widget màn hình chính).
String markdownToAndroidHtml(String text) =>
    _Writer(html: true).blocks(_parse(text));

/// Markdown → chữ trơn đã gỡ ký hiệu, gạch đầu dòng thành "• ".
String markdownToPlain(String text) =>
    _Writer(html: false).blocks(_parse(text));
