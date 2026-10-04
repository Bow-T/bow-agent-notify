import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/version.dart';
import '../themes/bow_theme.dart';
import 'icon3d.dart';
import 'wallpaper.dart';

/// Khung chung của mọi màn: hình nền Cực quang + thanh trạng thái trong suốt + dòng thương hiệu ở đầu.
class BowScaffold extends StatelessWidget {
  const BowScaffold({
    super.key,
    required this.children,
    this.action,
    this.bottom,
  });

  final List<Widget> children;
  final Widget? action;
  final Widget? bottom;

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
                  padding: const EdgeInsets.fromLTRB(20, 14, 14, 6),
                  child: Row(
                    children: [
                      const Icon3d('logo_mark', size: 36),
                      const SizedBox(width: 10),
                      Text(
                        'BOW',
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Notify',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Số phiên bản: biết máy đang cài bản nào mà không phải vào Cài đặt của điện thoại.
                      Text(
                        'v$appVersion',
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ),
                      const Spacer(),
                      ?action,
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: children,
                  ),
                ),
                if (bottom != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: bottom,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
