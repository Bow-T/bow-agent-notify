import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';
import 'glass.dart';
import 'icon3d.dart';

/// Một mục của thanh điều hướng dưới. `badge` > 0 thì hiện chấm đỏ kèm số (thẻ đang chờ).
typedef NavItem = ({String icon, String label, int badge});

/// Thanh điều hướng dưới: một viên kính nổi, mỗi mục một icon 3D + nhãn; mục đang mở có nền màu nhấn nhạt.
class BowBottomNav extends StatelessWidget {
  const BowBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Glass(
      radius: 33,
      tint: c.thick,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (final (i, item) in items.indexed)
            Expanded(
              child: _NavButton(
                item: item,
                selected: i == index,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            height: 54,
            decoration: selected
                ? BoxDecoration(
                    color: c.accent.withValues(alpha: c.isDark ? 0.26 : 0.13),
                    borderRadius: BorderRadius.circular(27),
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Số thẻ chờ bám vào góc icon, không trôi theo bề ngang của mục.
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon3d(item.icon, size: 27),
                    if (item.badge > 0)
                      Positioned(top: -4, right: -9, child: _Badge(item.badge)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? c.accent : c.muted,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

class _Badge extends StatelessWidget {
  const _Badge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.danger,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
