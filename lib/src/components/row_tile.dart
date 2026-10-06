import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';
import 'glass.dart';
import 'icon3d.dart';

/// Một dòng trên tấm kính: icon 3D, tên, dòng phụ, và thứ nằm cuối dòng. Có [onTap] thì cả dòng bấm được và cuối
/// dòng là mũi tên (trừ khi đã truyền [trailing]).
class RowTile extends StatelessWidget {
  const RowTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
  });

  final String icon;
  final String title;
  final String? subtitle;

  /// Màu dòng phụ khi nó là một cảnh báo (mặc định: màu chữ mờ).
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    const radius = 22.0;
    return Glass(
      radius: radius,
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Icon3d(icon, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle case final subtitle?)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: subtitleColor ?? c.muted,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing case final trailing?)
                  trailing
                else if (onTap != null)
                  Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
