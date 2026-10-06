import 'package:bow_notify/src/pages/home/widgets/onboarding_card.dart';
import 'package:bow_notify/src/themes/bow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Thẻ lần đầu mở app. Máy thử chạy tiếng Anh nên nhãn là bản tiếng Anh.

Future<List<String>> _pump(
  WidgetTester tester, {
  bool busy = false,
  Bow tokens = Bow.light,
}) async {
  final taps = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: bowTheme(tokens),
      home: Scaffold(
        body: OnboardingCard(
          busy: busy,
          onScan: () => taps.add('scan'),
          onPaste: () => taps.add('paste'),
        ),
      ),
    ),
  );
  return taps;
}

void main() {
  testWidgets('có nút quét và lối dán mã', (tester) async {
    final taps = await _pump(tester);
    await tester.tap(find.text('Scan pairing code'));
    await tester.tap(find.text('Cannot scan? Paste the pairing code'));
    expect(taps, ['scan', 'paste']);
  });

  testWidgets('brutal: dựng được, nút viết hoa, và gỡ khỏi màn không lỗi', (
    tester,
  ) async {
    final taps = await _pump(tester, tokens: Bow.brutal);
    await tester.tap(find.text('SCAN PAIRING CODE'));
    expect(taps, ['scan']);
    // Dấu logo của brutal không chạy hoạt ảnh — lúc gỡ không được dựng bộ điều khiển hoạt ảnh lần đầu.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('đang ghép: cả hai lối bị khoá', (tester) async {
    final taps = await _pump(tester, busy: true);
    await tester.tap(find.text('Pairing…'));
    await tester.tap(find.text('Cannot scan? Paste the pairing code'));
    expect(taps, isEmpty);
  });
}
