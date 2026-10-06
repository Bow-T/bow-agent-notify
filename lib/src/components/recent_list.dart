import 'package:flutter/material.dart';

import 'glass.dart';
import 'icon3d.dart';
import '../models/received.dart';
import '../themes/bow_theme.dart';

/// "Vừa nhận": các thông báo tới lúc app đang mở — mới nhất trước.
class RecentList extends StatelessWidget {
  const RecentList({super.key, required this.items});

  final List<Received> items;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Glass(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0) Divider(height: 1, color: c.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon3d(kindIcon(item.kind), size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: c.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.body.isNotEmpty)
                          Text(
                            item.body,
                            style: TextStyle(color: c.muted, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    TimeOfDay.fromDateTime(item.at).format(context),
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
