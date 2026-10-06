import 'package:bow_notify/src/components/bottom_nav.dart';
import 'package:bow_notify/src/themes/bow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _pump(WidgetTester tester, {required int badge}) async {
  final taps = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: bowTheme(Brightness.light),
      home: Scaffold(
        body: BowBottomNav(
          index: 0,
          onTap: taps.add,
          items: [
            (icon: 'bell', label: 'Today', badge: badge),
            (icon: 'gear', label: 'Settings', badge: 0),
          ],
        ),
      ),
    ),
  );
  return taps;
}

void main() {
  testWidgets('bấm một mục báo đúng vị trí của nó', (tester) async {
    final taps = await _pump(tester, badge: 0);
    await tester.tap(find.text('Settings'));
    await tester.tap(find.text('Today'));
    expect(taps, [1, 0]);
  });

  testWidgets('số thẻ chờ chỉ hiện khi lớn hơn 0', (tester) async {
    await _pump(tester, badge: 0);
    expect(find.text('0'), findsNothing);
    await _pump(tester, badge: 3);
    expect(find.text('3'), findsOneWidget);
    await _pump(tester, badge: 120);
    expect(find.text('99+'), findsOneWidget);
  });
}
