import 'dart:ui';

import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

/// Tấm nền của mọi thẻ. Theme kính: làm mờ thứ phía sau → nhuộm → ánh sáng đổ từ trên xuống, viền bắt sáng, bóng đổ
/// mềm. Theme brutal: khối ĐẶC màu thẻ, viền mực dày, bóng cứng, góc vuông ([radius] bị bỏ qua).
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Nhuộm thêm một màu (thẻ cảnh báo). Brutal pha màu này lên nền thẻ đặc.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    if (c.isBrutal) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tint == null ? c.surface : Color.alphaBlend(tint!, c.surface),
          border: Border.all(color: c.ink, width: c.line),
          boxShadow: c.hardShadow(4),
        ),
        child: Padding(padding: padding, child: child),
      );
    }
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 36,
            spreadRadius: -18,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(color: tint ?? c.paneTint),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                border: Border.all(color: c.rim),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: c.pane,
                ),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
