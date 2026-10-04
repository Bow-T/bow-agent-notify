import 'package:flutter/material.dart';

/// Icon "kẹo 3D" của web bow (bow-agent, `web/icons3d.ts`), dựng sẵn thành PNG ở `assets/icons/` bằng
/// `tool/export_icons.mts` + `tool/render_icons.sh`. `logo_mark` = logo của app (robot agent + chuông).
class Icon3d extends StatelessWidget {
  const Icon3d(this.name, {super.key, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/$name.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
  );
}
