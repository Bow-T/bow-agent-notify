import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/bow_scaffold.dart';
import '../../components/recent_list.dart';
import '../../components/row_tile.dart';
import '../../components/section_title.dart';
import '../../utils/l10n.dart';
import '../home/home_vm.dart';

/// Mục "Hoạt động": mọi thông báo đã tới từ lúc mở app, mới nhất trước.
class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(homeVmProvider.select((s) => s.recent));
    return ListView(
      padding: BowScaffold.listPadding(nav: true),
      children: [
        if (recent.isEmpty)
          RowTile(
            icon: 'activity',
            title: t('Chưa có hoạt động nào', 'No activity yet'),
            subtitle: t(
              'Thông báo tới trong lúc app đang mở sẽ hiện ở đây.',
              'Notifications that arrive while the app is open show up here.',
            ),
          )
        else ...[
          SectionTitle(
            t(
              'Từ lúc mở app · ${recent.length}',
              'Since the app opened · ${recent.length}',
            ),
          ),
          RecentList(items: recent),
        ],
      ],
    );
  }
}
