import '../utils/l10n.dart';
import 'pending_card.dart';

/// Một nút trên thông báo. `opensApp` = bấm là mở app (không gửi gì).
typedef CardAction = ({String id, String title, bool opensApp});

/// Câu hỏi "gọn" trả lời được ngay trên thông báo: đúng một câu, chọn một, tối đa ba lựa chọn (Android hiện tối đa ba nút).
Question? _quickQuestion(PendingCard card) {
  if (card.kind != 'question' || card.questions.length != 1) return null;
  final q = card.questions.single;
  return !q.multiSelect && q.options.isNotEmpty && q.options.length <= 3
      ? q
      : null;
}

/// Android hiện tối đa ba nút trên một thông báo.
const _maxActions = 3;

/// Các nút của một thẻ.
List<CardAction> cardActions(PendingCard card) {
  if (card.kind == 'reply') {
    // Lời mời trả lời: mỗi câu một nút (ba câu đầu — câu agent mời đứng trước "tiếp" / "commit/push").
    return [
      for (final (i, option) in card.options.take(_maxActions).indexed)
        (id: 'say:$i', title: option, opensApp: false),
    ];
  }
  if (card.kind == 'approval') {
    return [
      card.risky
          ? (
              id: 'open',
              title: t('Mở để duyệt', 'Open to approve'),
              opensApp: true,
            )
          : (id: 'allow', title: t('Cho phép', 'Allow'), opensApp: false),
      (id: 'deny', title: t('Từ chối', 'Deny'), opensApp: false),
    ];
  }
  final q = _quickQuestion(card);
  if (q == null) {
    return [
      (id: 'open', title: t('Mở để trả lời', 'Open to answer'), opensApp: true),
    ];
  }
  return [
    for (final (i, option) in q.options.indexed)
      (id: 'opt:$i', title: option.label, opensApp: false),
  ];
}

/// Quyết định ứng với nút [actionId] của [card]; `null` = nút này không được gửi gì (kể cả khi mã nút bị giả):
/// thẻ rủi ro KHÔNG BAO GIỜ được "cho phép" từ thông báo.
Map<String, Object?>? replyForAction(PendingCard card, String actionId) {
  if (card.kind == 'reply') {
    final index = actionId.startsWith('say:')
        ? int.tryParse(actionId.substring(4))
        : null;
    if (index == null || index < 0 || index >= card.options.length) return null;
    return {'say': card.options[index]};
  }
  if (card.kind == 'approval') {
    if (actionId == 'deny') return {'allow': false};
    if (actionId == 'allow' && !card.risky) return {'allow': true};
    return null;
  }
  final q = _quickQuestion(card);
  final index = actionId.startsWith('opt:')
      ? int.tryParse(actionId.substring(4))
      : null;
  if (q == null || index == null || index < 0 || index >= q.options.length) {
    return null;
  }
  return {
    'answers': {q.question: q.options[index].label},
  };
}
