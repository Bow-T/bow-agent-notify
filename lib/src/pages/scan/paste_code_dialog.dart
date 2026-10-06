import 'package:flutter/material.dart';

import '../../components/glass_button.dart';
import '../../components/glass_dialog.dart';
import '../../utils/l10n.dart';

/// Hộp nhập mã ghép bằng tay (web bow → "Chép mã"): cho lúc không quét được — mở web bow trên chính điện thoại này,
/// máy không có camera. Ô nhập thường chứ không tự đọc clipboard: iOS hỏi quyền mỗi lần app tự đọc. Trả chuỗi đã
/// nhập (`null` = bấm Thôi); mã sai vẫn trả về — nơi ghép máy mới là nơi nói "đây không phải mã ghép của bow".
Future<String?> showPasteCodeDialog(BuildContext context) {
  final input = TextEditingController();
  return showGlassDialog<String>(
    context,
    title: t('Dán mã ghép', 'Paste pairing code'),
    content: TextField(
      controller: input,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      maxLines: 3,
      style: const TextStyle(fontSize: 14),
      decoration: const InputDecoration(hintText: 'bowpush://pair?…'),
    ),
    actions: (close) => [
      GlassButton(label: t('Thôi', 'Cancel'), onPressed: () => close(null)),
      GlassButton(
        label: t('Ghép', 'Pair'),
        kind: GlassButtonKind.primary,
        onPressed: () => close(input.text),
      ),
    ],
  );
}
