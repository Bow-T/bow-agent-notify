import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/bow_scaffold.dart';
import '../../components/choice_chips.dart';
import '../../components/glass_button.dart';
import '../../components/row_tile.dart';
import '../../models/mirror.dart';
import '../../themes/bow_theme.dart';
import '../../utils/l10n.dart';
import '../home/home_vm.dart';
import 'new_task_page.dart';
import 'tab_page.dart';
import 'tabs_vm.dart';
import 'widgets/machine_tabs_section.dart';

enum _Filter { all, running, waiting }

/// Mục "Tab": thanh tab của các trang bow đang mở trên máy — lọc theo trạng thái, chạm một tab để đọc hội thoại và
/// gõ tiếp, giao việc mới. Rỗng khi máy chưa bật "xem tab trên điện thoại".
class TabsPage extends ConsumerStatefulWidget {
  const TabsPage({super.key});

  @override
  ConsumerState<TabsPage> createState() => _TabsPageState();
}

class _TabsPageState extends ConsumerState<TabsPage> {
  var _filter = _Filter.all;

  bool _shown(MirrorTab tab) => switch (_filter) {
    _Filter.all => true,
    _Filter.running => tab.running,
    _Filter.waiting => tab.pending > 0,
  };

  void _open(MachineTabs machine, MirrorTab tab) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TabPage(
            tab: (
              topic: machine.pairing.topic,
              port: machine.port,
              tabId: tab.id,
            ),
          ),
        ),
      );

  void _newTask(MachineTabs machine) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => NewTaskPage(
        machine: (topic: machine.pairing.topic, port: machine.port),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final machines = [
      for (final machine in ref.watch(tabsVmProvider))
        if (machine.tabs.isNotEmpty) machine,
    ];
    if (machines.isEmpty) {
      final paired = ref.watch(
        homeVmProvider.select((s) => s.pairings.isNotEmpty),
      );
      return ListView(
        padding: BowScaffold.listPadding(nav: true),
        children: [
          RowTile(
            icon: 'layers',
            title: t('Chưa có tab nào', 'No tabs yet'),
            subtitle: paired
                ? t(
                    'Mở trang bow trên máy và bật "Xem tab và hội thoại trên điện thoại" ở Cài đặt → Thông báo điện thoại.',
                    'Open bow on the machine and turn on "View tabs and conversations on the phone" in Settings → Phone notifications.',
                  )
                : t(
                    'Ghép máy trước — tab của trang bow trên máy sẽ hiện ở đây.',
                    'Pair a machine first — the tabs of bow on that machine show up here.',
                  ),
          ),
        ],
      );
    }
    final now = DateTime.now();
    final tabs = [for (final machine in machines) ...machine.tabs];
    // Trang web đã im thì không: việc giao đi sẽ không ai nhận.
    final takers = [
      for (final machine in machines)
        if (machine.canNew && !machine.stale(now)) machine,
    ];
    // Chỉ một nơi nhận việc ⇒ một nút nổi cố định; nhiều nơi thì mỗi máy một nút ngay dưới danh sách của nó.
    final single = takers.length == 1 ? takers.first : null;
    final sections = [
      for (final machine in machines)
        if (machine.tabs.any(_shown))
          MachineTabsSection(
            machine: machine,
            tabs: machine.tabs.where(_shown).toList(),
            showHost: machines.length > 1,
            onOpen: (tab) => _open(machine, tab),
            onNewTask: single == null && takers.contains(machine)
                ? () => _newTask(machine)
                : null,
          ),
    ];
    return Stack(
      children: [
        ListView(
          padding: BowScaffold.listPadding(
            nav: true,
          ).add(EdgeInsets.only(bottom: single == null ? 0 : 60)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
              child: ChoiceChips<_Filter>(
                value: _filter,
                onChanged: (filter) => setState(() => _filter = filter),
                options: [
                  (_Filter.all, '${t('Tất cả', 'All')} · ${tabs.length}'),
                  (
                    _Filter.running,
                    '${t('Đang chạy', 'Running')} · ${tabs.where((tab) => tab.running).length}',
                  ),
                  (
                    _Filter.waiting,
                    '${t('Chờ bạn', 'Waiting')} · ${tabs.where((tab) => tab.pending > 0).length}',
                  ),
                ],
              ),
            ),
            ...sections,
            if (sections.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Text(
                  t(
                    'Không có tab nào ở trạng thái này.',
                    'No tabs in this state.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 13.5),
                ),
              ),
          ],
        ),
        if (single != null)
          Positioned(
            right: 16,
            bottom: BowScaffold.navClearance + 8,
            child: GlassButton(
              label: t('Giao việc mới', 'New task'),
              icon: Icons.add_rounded,
              kind: GlassButtonKind.primary,
              large: true,
              onPressed: () => _newTask(single),
            ),
          ),
      ],
    );
  }
}
