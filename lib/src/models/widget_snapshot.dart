import '../utils/l10n.dart';
import '../utils/markdown.dart';
import 'card_action.dart';
import 'pending_card.dart';
import 'received.dart';

/// Thứ widget màn hình chính (Android) cần để vẽ: khoá → chuỗi. Phía Kotlin (`BowWidgets.kt`) CHỈ đọc rồi gán vào
/// view — chữ nào hiện, nút nào có, đều quyết ở đây. Đổi tên khoá thì đổi cả hai bên.
///
/// Mọi giá trị là chuỗi (cờ = `'1'` / `''`): khỏi lệch kiểu giữa Dart và SharedPreferences của Android.

/// Phần CUỐI lời agent đưa lên widget (ký tự): widget 4×2 hiện được 2–4 dòng, mà lời mời trả lời nằm ở cuối.
const widgetTailChars = 170;

/// Android hiện vừa ba nút trên một hàng của widget 4 ô.
const widgetMaxActions = 3;

/// Thẻ widget đưa ra trước: thẻ đang CHẶN agent (xin duyệt, câu hỏi) đứng trên lời mời trả lời — lượt đã xong thì
/// chờ được, agent đang đứng thì không. Trong cùng nhóm: cũ nhất trước.
PendingCard? widgetCard(List<PendingCard> cards) {
  PendingCard? best;
  for (final card in cards) {
    if (best == null) {
      best = card;
      continue;
    }
    final blocks = card.kind != 'reply';
    final bestBlocks = best.kind != 'reply';
    if (blocks != bestBlocks ? blocks : card.at.isBefore(best.at)) best = card;
  }
  return best;
}

String _clock(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

/// "Việc gần nhất" widget hiện khi không còn gì chờ chỉ tính lượt ĐÃ XONG / LỖI. Thông báo xin duyệt / câu hỏi thì
/// không: duyệt xong rồi mà widget còn ghi "cần bạn duyệt" là báo sai.
bool isWidgetEvent(String kind) => kind == 'done' || kind == 'fatal';

String _listening(int machines) => t(
  'Đang nghe $machines máy',
  'Listening to $machines machine${machines == 1 ? '' : 's'}',
);

Map<String, String> widgetSnapshot({
  required List<PendingCard> cards,
  required int machines,
  required DateTime now,
  Received? last,
  bool busy = false,
}) {
  final card = widgetCard(cards);
  final count = cards.length;
  final actions = card == null
      ? const <CardAction>[]
      : cardActions(card).take(widgetMaxActions).toList();
  final label = card == null
      ? ''
      : card.label.isEmpty
      ? t('Tác vụ', 'Task')
      : card.label;
  return {
    'w_machines': '$machines',
    'w_updated_ms': '${now.millisecondsSinceEpoch}',
    'w_count': '$count',
    'w_badge': count == 0 ? '' : t('$count chờ', '$count waiting'),
    'w_host': card?.pairing.host ?? '',
    'w_busy': busy ? '1' : '',
    // ── thẻ đang chờ ──
    'w_card': card == null ? '' : '1',
    'w_kind': card?.kind ?? '',
    'w_label': label,
    'w_risky': card?.risky == true ? '1' : '',
    // Thẻ trả lời mang lời agent (Markdown): `w_html` là bản đã đổi cho widget dựng đậm / code / gạch đầu dòng, và
    // `w_text` là bản chữ trơn. Thẻ duyệt mang LỆNH: `w_html` rỗng, `w_text` giữ nguyên từng ký tự (chữ đều nét).
    'w_text': card == null
        ? ''
        : card.kind == 'reply'
        ? markdownToPlain(markdownTail(card.text, widgetTailChars))
        : card.text,
    'w_html': card?.kind == 'reply'
        ? markdownToAndroidHtml(markdownTail(card!.text, widgetTailChars))
        : '',
    // Chỉ là mã định danh: nút bấm gửi nó về Dart, Dart đọc lại thẻ thật rồi mới gửi quyết định.
    'w_ref': card == null
        ? ''
        : 't=${Uri.encodeQueryComponent(card.pairing.topic)}'
              '&p=${Uri.encodeQueryComponent(card.port)}'
              '&i=${Uri.encodeQueryComponent(card.id)}',
    for (var i = 0; i < widgetMaxActions; i++) ...{
      'w_a${i}_id': i < actions.length ? actions[i].id : '',
      'w_a${i}_title': i < actions.length ? actions[i].title : '',
      'w_a${i}_opens': i < actions.length && actions[i].opensApp ? '1' : '',
    },
    // ── không có gì chờ ──
    'w_empty_icon': machines == 0
        ? 'logo'
        : last?.kind == 'fatal'
        ? 'fatal'
        : 'done',
    'w_empty_title': machines == 0
        ? t('Chưa ghép máy nào', 'Nothing paired yet')
        : t('Không có gì chờ bạn', 'Nothing is waiting'),
    'w_empty_sub': machines == 0
        ? t('Mở app để quét mã ghép', 'Open the app to scan the pairing code')
        : last == null
        ? _listening(machines)
        : '${last.title}${last.body.isEmpty ? '' : ' · ${last.body}'} · ${_clock(last.at)}',
    // ── viên thuốc trạng thái ──
    'w_status_icon': card?.kind ?? 'logo',
    'w_status_title': count > 0
        ? t('$count việc chờ bạn', '$count waiting for you')
        : machines == 0
        ? t('Chưa ghép máy', 'Not paired')
        : t('Không có gì chờ', 'All clear'),
    'w_status_sub': count > 0
        ? label
        : machines == 0
        ? t('Mở app để ghép', 'Open the app to pair')
        // Viên thuốc hẹp: câu ngắn hơn bản ở widget lớn.
        : t(
            'Nghe $machines máy',
            '$machines machine${machines == 1 ? '' : 's'}',
          ),
  };
}
