import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/bow_theme.dart';
import 'icon3d.dart';
import 'wallpaper.dart';

/// Khung chung của các màn gốc: hình nền Cực quang + thanh trạng thái trong suốt + dòng thương hiệu ở đầu. Có [nav]
/// thì thanh điều hướng NỔI trên nội dung, nên danh sách trong [body] phải chừa đáy bằng [listPadding].
class BowScaffold extends StatelessWidget {
  const BowScaffold({super.key, required this.body, this.action, this.nav});

  /// Chiều cao phần đáy bị thanh điều hướng nổi che.
  static const navClearance = 84.0;

  /// Lề của một danh sách cuộn trong khung; `nav` = màn nằm dưới thanh điều hướng.
  static EdgeInsets listPadding({bool nav = false}) =>
      EdgeInsets.fromLTRB(16, 10, 16, 24 + (nav ? navClearance : 0));

  final Widget body;
  final Widget? action;
  final Widget? nav;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Wallpaper(
          child: SafeArea(
            child: Stack(
              children: [
                Column(
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
                          const Spacer(),
                          // Không có nút thì vẫn giữ đúng chiều cao của hàng (nút icon cao 48).
                          action ?? const SizedBox(height: 48),
                        ],
                      ),
                    ),
                    Expanded(child: body),
                  ],
                ),
                if (nav case final nav?)
                  Positioned(left: 12, right: 12, bottom: 10, child: nav),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
