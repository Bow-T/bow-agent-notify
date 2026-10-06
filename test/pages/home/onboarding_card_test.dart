import 'package:bow_notify/src/pages/home/widgets/onboarding_card.dart';
import 'package:bow_notify/src/themes/bow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Thẻ lần đầu mở app. Máy thử chạy tiếng Anh nên nhãn là bản tiếng Anh.

Future<List<String>> _pump(WidgetTester tester, {bool busy = false}) async {
  final taps = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: bowTheme(Brightness.light),
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

  testWidgets('đang ghép: cả hai lối bị khoá', (tester) async {
    final taps = await _pump(tester, busy: true);
    await tester.tap(find.text('Pairing…'));
    await tester.tap(find.text('Cannot scan? Paste the pairing code'));
    expect(taps, isEmpty);
  });
}
