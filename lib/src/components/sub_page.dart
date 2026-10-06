import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/bow_theme.dart';
import '../utils/l10n.dart';
import 'bow_scaffold.dart';
import 'wallpaper.dart';

/// Khung của một màn CON mở từ Cài đặt (Âm báo, Chẩn đoán, Hướng dẫn): hình nền, nút quay lại + tên màn, rồi một
/// danh sách cuộn.
class SubPage extends StatelessWidget {
  const SubPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Wallpaper(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: t('Quay lại', 'Back'),
                        icon: Icon(Icons.arrow_back_rounded, color: c.ink),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: BowScaffold.listPadding(),
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
