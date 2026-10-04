import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

/// Tiêu đề một nhóm trong danh sách (chữ nhỏ, viết hoa, giãn chữ).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Bow.of(context).muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}
