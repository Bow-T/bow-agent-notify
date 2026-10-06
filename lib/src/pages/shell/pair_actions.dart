import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/l10n.dart';
import '../home/home_vm.dart';
import '../scan/paste_code_dialog.dart';
import '../scan/scan_page.dart';

// Việc ghép máy mở được từ nhiều chỗ (nút quét ở thanh trên, thẻ lần đầu, Cài đặt) — gom ở đây để mọi chỗ đi cùng
// một đường và nói lại kết quả cùng một cách.

/// Hiện câu ViewModel trả về (`null` = không có gì để nói).
void say(BuildContext context, String? text) {
  if (text == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<void> _pair(BuildContext context, WidgetRef ref, String? raw) async {
  final result = await ref.read(homeVmProvider.notifier).pair(raw);
  if (context.mounted) say(context, result);
}

/// Mở màn quét mã rồi ghép với mã vừa quét (hoặc vừa dán trong màn đó).
Future<void> scanAndPair(BuildContext context, WidgetRef ref) async {
  final raw = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => ScanPage(
        title: t('Quét mã ghép', 'Scan pairing code'),
        hint: t(
          'Đưa camera vào mã QR ở web bow: Cài đặt → Thông báo điện thoại.',
          'Point at the QR code in bow: Settings → Phone notifications.',
        ),
      ),
    ),
  );
  if (context.mounted) await _pair(context, ref, raw);
}

/// Mở thẳng hộp dán mã rồi ghép.
Future<void> pasteAndPair(BuildContext context, WidgetRef ref) async {
  final raw = await showPasteCodeDialog(context);
  if (context.mounted) await _pair(context, ref, raw);
}
