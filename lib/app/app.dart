import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/models/appearance.dart';
import '../src/pages/settings/appearance_vm.dart';
import '../src/pages/setup/setup_needed_page.dart';
import '../src/pages/shell/shell_page.dart';
import '../src/themes/bow_theme.dart';

class BowNotifyApp extends ConsumerWidget {
  const BowNotifyApp({super.key, this.firebaseError});

  /// Khác `null` = bản build thiếu cấu hình Firebase — hiện màn hướng dẫn thay cho màn chính.
  final String? firebaseError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceVmProvider);
    final brutal = appearance.style == BowStyle.brutal;
    return MaterialApp(
      title: 'Bow Notify',
      debugShowCheckedModeBanner: false,
      // Brutal chỉ có một bản sáng ⇒ cả hai ngả đều là nó, máy đặt tối cũng không đổi.
      theme: bowTheme(brutal ? Bow.brutal : Bow.light),
      darkTheme: bowTheme(brutal ? Bow.brutal : Bow.dark),
      themeMode: switch (appearance.mode) {
        _ when brutal => ThemeMode.light,
        GlassMode.system => ThemeMode.system,
        GlassMode.light => ThemeMode.light,
        GlassMode.dark => ThemeMode.dark,
      },
      // Chữ của app tính lúc dựng widget (`t()`), nhiều màn lại là const ⇒ đổi ngôn ngữ thì dựng lại cả cây.
      home: KeyedSubtree(
        key: ValueKey(appearance.language),
        child: firebaseError == null
            ? const ShellPage()
            : SetupNeededPage(error: firebaseError!),
      ),
    );
  }
}
