import 'package:flutter/material.dart';

import '../../../components/glass.dart';
import '../../../components/glass_button.dart';
import '../../../components/icon3d.dart';
import '../../../components/section_title.dart';
import '../../../models/mirror.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';
import '../../tabs/tab_page.dart';

/// "Tab trên máy": thanh tab của một trang bow — tab nào đang chạy, tab nào đang chờ bạn. Chạm vào một tab để đọc
/// hội thoại của nó; máy cho phép thì có nút giao việc mới (mở tab mới).
class MachineTabsSection extends StatelessWidget {
  const MachineTabsSection({
    super.key,
    required this.machine,
    required this.showHost,
    required this.onOpen,
    required this.onNewTask,
  });

  final MachineTabs machine;

  /// Ghép nhiều máy / nhiều cổng thì tiêu đề ghi rõ là máy nào.
  final bool showHost;
  final void Function(MirrorTab tab) onOpen;

  /// Mở màn "Giao việc mới" cho trang bow này — nút chỉ hiện khi máy cho phép và trang web còn sống.
  final VoidCallback onNewTask;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final title = t('Tab trên máy', 'Tabs on the machine');
    final stale = machine.stale(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          showHost
              ? '$title · ${machine.pairing.host}:${machine.port}'
              : '$title · ${machine.tabs.length}',
        ),
        if (stale)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StaleNote(machine: machine),
          ),
        Glass(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final (index, tab) in machine.tabs.indexed) ...[
                if (index > 0)
                  Divider(height: 1, indent: 56, color: c.hairline),
                InkWell(
                  onTap: () => onOpen(tab),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: tab.running
                              ? Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: c.accent,
                                  ),
                                )
                              : Icon3d(
                                  tab.pending > 0 ? 'shield' : 'chat',
                                  size: 30,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tab.title.isEmpty
                                    ? t('Tab mới', 'New tab')
                                    : tab.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.ink,
                                  fontSize: 15,
                                  fontWeight: tab.id == machine.active
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                              Text(
                                [
                                  if (tab.project.isNotEmpty) tab.project,
                                  tab.pending > 0
                                      ? t(
                                          '${tab.pending} thẻ chờ bạn',
                                          '${tab.pending} waiting for you',
                                        )
                                      : tab.running
                                      ? t('đang chạy', 'running')
                                      : t('đứng yên', 'idle'),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tab.pending > 0 ? c.accent : c.muted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.muted),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Trang web đã im thì không: lệnh gửi đi sẽ không ai nhận.
        if (machine.canNew && !stale)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GlassButton(
              label: t('Giao việc mới', 'New task'),
              icon: Icons.add_rounded,
              onPressed: onNewTask,
            ),
          ),
      ],
    );
  }
}
