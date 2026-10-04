import 'dart:io';

import 'package:bow_notify/src/constants/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('số phiên bản hiện trong app khớp pubspec.yaml', () {
    final line = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.split(':').last.trim().split('+').first, appVersion);
  });
}
