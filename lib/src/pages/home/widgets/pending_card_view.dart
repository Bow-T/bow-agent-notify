import 'package:flutter/material.dart';

import '../../../components/glass.dart';
import '../../../components/glass_button.dart';
import '../../../components/icon3d.dart';
import '../../../components/markdown_text.dart';
import '../../../models/pending_card.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';

/// Một thẻ đang chờ trên máy chạy bow: xin duyệt (Cho phép / Từ chối) hoặc câu hỏi (chọn đáp án rồi Gửi).
class PendingCardView extends StatefulWidget {
  const PendingCardView({
    super.key,
    required this.card,
    required this.busy,
    required this.onDecide,
  });

  final PendingCard card;
  final bool busy;

  /// `{allow: bool}` cho thẻ duyệt; `{answers: {câu hỏi: nhãn đã chọn} | null}` cho câu hỏi (null = bỏ qua);
  /// `{say: câu}` cho lời mời trả lời.
  final void Function(Map<String, Object?> reply) onDecide;

  @override
  State<PendingCardView> createState() => _PendingCardViewState();
}

class _PendingCardViewState extends State<PendingCardView> {
  /// Đáp án đang chọn: câu hỏi → các nhãn.
  final Map<String, Set<String>> _picks = {};

  bool _picked(Question q, String label) =>
      _picks[q.question]?.contains(label) ?? false;

  void _toggle(Question q, String label) {
    setState(() {
      final picks = _picks.putIfAbsent(q.question, () => {});
      if (!q.multiSelect) {
        picks
          ..clear()
          ..add(label);
      } else if (!picks.remove(label)) {
        picks.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final card = widget.card;
    final isQuestion = card.kind == 'question';
    final isReply = card.kind == 'reply';
    final answered = card.questions.every(
      (q) => _picks[q.question]?.isNotEmpty ?? false,
    );
    final onDecide = widget.busy ? null : widget.onDecide;
    return Glass(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon3d(
                isReply
                    ? 'success'
                    : isQuestion
                    ? 'chat'
                    : 'shield',
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.label.isEmpty ? t('Tác vụ', 'Task') : card.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        if (card.pairing.host.isNotEmpty) card.pairing.host,
                        if (card.tool.isNotEmpty) card.tool,
                        TimeOfDay.fromDateTime(card.at).format(context),
                      ].join(' · '),
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (card.risky) ...[
                const Icon3d('warning', size: 22),
                const SizedBox(width: 4),
                Text(
                  t('Rủi ro', 'Risky'),
                  style: TextStyle(
                    color: c.dangerInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (!isQuestion)
            // Ô lõm chứa thứ cần xem: lệnh / file cần duyệt, hoặc lời agent của lượt vừa xong. Cuộn được khi dài.
            Container(
              width: double.infinity,
              // Lời agent dài hơn một lệnh: cho ô cao hơn (vẫn cuộn được).
              constraints: BoxConstraints(maxHeight: isReply ? 280 : 190),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.well,
                borderRadius: c.radius(12),
                border: Border.all(color: c.hairline, width: c.line),
              ),
              child: SingleChildScrollView(
                // Lời agent: mở ra ở CUỐI (nơi agent mời trả lời), cuộn lên để đọc phần trước.
                reverse: isReply,
                child: isReply
                    // Lời agent là Markdown (đậm, danh sách, code…) — dựng cho đúng, không hiện nguyên ký hiệu.
                    ? MarkdownText(card.text)
                    // Lệnh / file cần duyệt: giữ NGUYÊN từng ký tự, chữ đều nét (dấu * hay _ trong lệnh là nội dung).
                    : SelectableText(
                        card.text,
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 13,
                          height: 1.4,
                          fontFamily: 'monospace',
                          fontFamilyFallback: const ['Menlo', 'Courier'],
                        ),
                      ),
              ),
            )
          else
            for (final q in card.questions) ...[
              Text(
                q.question,
                style: TextStyle(
                  color: c.ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              for (final option in q.options)
                InkWell(
                  borderRadius: c.radius(12),
                  onTap: widget.busy ? null : () => _toggle(q, option.label),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ô chọn phẳng một màu (như bộ tiện ích của web): phải đổi màu theo trạng thái.
                        Icon(
                          switch ((_picked(q, option.label), q.multiSelect)) {
                            (true, true) => Icons.check_box_rounded,
                            (true, false) => Icons.radio_button_checked_rounded,
                            (false, true) =>
                              Icons.check_box_outline_blank_rounded,
                            (false, false) =>
                              Icons.radio_button_unchecked_rounded,
                          },
                          size: 22,
                          color: _picked(q, option.label)
                              ? c.accentInk
                              : c.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.label,
                                style: TextStyle(color: c.ink, fontSize: 14.5),
                              ),
                              if (option.description.isNotEmpty)
                                Text(
                                  option.description,
                                  style: TextStyle(
                                    color: c.muted,
                                    fontSize: 12.5,
                                    height: 1.35,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
            ],
          const SizedBox(height: 12),
          if (isReply)
            // Lời mời trả lời: mỗi câu một nút — bấm là tab trên máy gửi đúng câu đó. Không có "từ chối": không
            // chọn gì thì lượt cứ nằm đó như khi bạn rời bàn.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, option) in card.options.indexed)
                  GlassButton(
                    label: widget.busy ? t('Đang gửi…', 'Sending…') : option,
                    kind: i == 0
                        ? GlassButtonKind.primary
                        : GlassButtonKind.plain,
                    onPressed: onDecide == null
                        ? null
                        : () => onDecide({'say': option}),
                  ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: isQuestion
                        ? t('Bỏ qua', 'Skip')
                        : t('Từ chối', 'Deny'),
                    kind: isQuestion
                        ? GlassButtonKind.plain
                        : GlassButtonKind.deny,
                    onPressed: onDecide == null
                        ? null
                        : () => onDecide(
                            isQuestion ? {'answers': null} : {'allow': false},
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassButton(
                    label: widget.busy
                        ? t('Đang gửi…', 'Sending…')
                        : isQuestion
                        ? t('Gửi', 'Send')
                        : t('Cho phép', 'Allow'),
                    // Vân tay = icon phẳng trắng trên nền lam (hình 3D chìm trên nền màu nhấn).
                    icon: card.risky ? Icons.fingerprint_rounded : null,
                    kind: isQuestion
                        ? GlassButtonKind.primary
                        : GlassButtonKind.allow,
                    onPressed: onDecide == null || (isQuestion && !answered)
                        ? null
                        : () => onDecide(
                            isQuestion
                                ? {
                                    'answers': {
                                      for (final q in card.questions)
                                        q.question: _picks[q.question]!.join(
                                          ', ',
                                        ),
                                    },
                                  }
                                : {'allow': true},
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
