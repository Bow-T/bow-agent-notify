import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

/// Tiêu đề một nhóm trong danh sách (chữ nhỏ, viết hoa, giãn chữ). Có [action] thì cuối dòng là một lối tắt bấm được
/// ("Xem tất cả").
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                color: c.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (action case final action?)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  action,
                  style: TextStyle(
                    color: c.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
