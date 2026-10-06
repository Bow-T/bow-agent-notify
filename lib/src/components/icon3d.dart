import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

/// Icon "kẹo 3D" của web bow (bow-agent, `web/icons3d.ts`), dựng sẵn thành PNG ở `assets/icons/` bằng
/// `tool/export_icons.mts` + `tool/render_icons.sh`. `logo_mark` = logo của app (robot agent + chuông).
///
/// Theme brutal: thêm VIỀN MỰC + bóng cứng quanh hình — cùng ngôn ngữ với nút / thẻ (web làm bằng chuỗi `drop-shadow`
/// không nhoè của `.bow-ic-3d`; ở đây là các bản tô mực của chính hình đó, lệch một điểm ảnh về bốn phía).
class Icon3d extends StatelessWidget {
  const Icon3d(this.name, {super.key, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/icons/$name.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
    final c = Bow.of(context);
    if (!c.isBrutal) return image;
    Widget inked(double dx, double dy) => Transform.translate(
      offset: Offset(dx, dy),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(c.ink, BlendMode.srcIn),
        child: image,
      ),
    );
    return Stack(
      children: [
        inked(1, 0),
        inked(-1, 0),
        inked(0, 1),
        inked(0, -1),
        inked(1.5, 1.5),
        image,
      ],
    );
  }
}
