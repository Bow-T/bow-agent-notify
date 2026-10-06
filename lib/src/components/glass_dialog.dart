import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

import 'glass.dart';

/// Hộp thoại bằng kính. `actions` nhận hàm đóng hộp kèm kết quả.
Future<T?> showGlassDialog<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  required List<Widget> Function(void Function(T? result) close) actions,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0x520A1020),
    builder: (context) {
      final c = Bow.of(context);
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: Glass(
          tint: c.thick,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: c.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              DefaultTextStyle.merge(
                style: TextStyle(color: c.ink, fontSize: 14.5, height: 1.45),
                child: content,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: actions((result) => Navigator.pop(context, result)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
