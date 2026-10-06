import 'package:flutter/material.dart';

import '../src/pages/shell/shell_page.dart';
import '../src/pages/setup/setup_needed_page.dart';
import '../src/themes/bow_theme.dart';

class BowNotifyApp extends StatelessWidget {
  const BowNotifyApp({super.key, this.firebaseError});

  /// Khác `null` = bản build thiếu cấu hình Firebase — hiện màn hướng dẫn thay cho màn chính.
  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bow Notify',
      debugShowCheckedModeBanner: false,
      theme: bowTheme(Brightness.light),
      darkTheme: bowTheme(Brightness.dark),
      home: firebaseError == null
          ? const ShellPage()
          : SetupNeededPage(error: firebaseError!),
    );
  }
}
