import 'package:bow_notify/src/pages/home/widgets/status_card.dart';
import 'package:bow_notify/src/themes/bow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nút quét trong thẻ đầu màn hình: máy thử chạy tiếng Anh nên nhãn là "Scan pairing code".
Future<void> _pump(
  WidgetTester tester, {
  required int machines,
  required VoidCallback onScan,
  bool busy = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: bowTheme(Brightness.light),
    home: Scaffold(
      body: StatusCard(
        machines: machines,
        active: false,
        busy: busy,
        onScan: onScan,
      ),
    ),
  ),
);

void main() {
  testWidgets('chưa ghép máy nào: thẻ có nút quét, bấm là mở màn quét', (
    tester,
  ) async {
    var scans = 0;
    await _pump(tester, machines: 0, onScan: () => scans++);
    await tester.tap(find.text('Scan pairing code'));
    expect(scans, 1);
  });

  testWidgets('đang ghép: nút bị khoá', (tester) async {
    var scans = 0;
    await _pump(tester, machines: 0, busy: true, onScan: () => scans++);
    await tester.tap(find.text('Pairing…'));
    expect(scans, 0);
  });

  testWidgets('đã có máy: thẻ không còn nút quét (chỉ còn icon ở thanh trên)', (
    tester,
  ) async {
    await _pump(tester, machines: 1, onScan: () {});
    expect(find.text('Scan pairing code'), findsNothing);
  });
}
