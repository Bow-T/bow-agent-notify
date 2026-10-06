import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/bottom_nav.dart';
import '../../components/bow_scaffold.dart';
import '../../components/icon3d.dart';
import '../../utils/l10n.dart';
import '../activity/activity_page.dart';
import '../home/home_page.dart';
import '../home/home_vm.dart';
import '../settings/settings_page.dart';
import '../settings/update_vm.dart';
import '../tabs/tabs_page.dart';
import '../tabs/tabs_vm.dart';
import '../tabs/typing_gate.dart';
import 'pair_actions.dart';
import 'shell_vm.dart';

/// Khung của app: thanh trên (logo + nút quét mã), bốn mục ở thanh điều hướng dưới, và vòng đời của app — ra nền thì
/// thôi hỏi máy + khoá quyền gõ lệnh, trở lại thì đọc lại ngay. Mỗi mục là một màn riêng, giữ nguyên trạng thái khi
/// chuyển qua lại.
class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Hỏi bản mới sau khung hình đầu (provider không được đổi trong lúc cây widget đang dựng).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(updateVmProvider.notifier).autoCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final home = ref.read(homeVmProvider.notifier);
    final tabs = ref.read(tabsVmProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      home.resumed();
      tabs.resumed();
      ref.read(updateVmProvider.notifier).autoCheck();
    } else {
      home.paused();
      tabs.paused();
      // App ra nền: khoá lại quyền gõ lệnh (lần sau phải qua vân tay).
      ref.read(typingGateProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(shellVmProvider);
    final busy = ref.watch(homeVmProvider.select((s) => s.busy));
    final pending = ref.watch(homeVmProvider.select((s) => s.pending.length));
    final update = ref.watch(updateVmProvider.select((s) => s.offer));
    final shell = ref.read(shellVmProvider.notifier);
    return PopScope(
      // Nút Back của Android ở mục khác: về Hôm nay trước, ở Hôm nay mới thoát app.
      canPop: tab == ShellTab.today,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.open(ShellTab.today);
      },
      child: BowScaffold(
        // Ghép máy là việc làm MỘT lần ⇒ chỉ là một nút nhỏ ở thanh trên.
        action: IconButton(
          onPressed: busy ? null : () => scanAndPair(context, ref),
          tooltip: t('Quét mã ghép', 'Scan pairing code'),
          icon: const Icon3d('qr', size: 30),
        ),
        nav: BowBottomNav(
          index: tab.index,
          onTap: (i) => shell.open(ShellTab.values[i]),
          items: [
            (icon: 'bell', label: t('Hôm nay', 'Today'), badge: pending),
            (icon: 'layers', label: t('Tab', 'Tabs'), badge: 0),
            (icon: 'activity', label: t('Hoạt động', 'Activity'), badge: 0),
            // Chấm ở Cài đặt = có bản mới của app (gạt dải báo ở Hôm nay đi thì chấm vẫn còn).
            (
              icon: 'gear',
              label: t('Cài đặt', 'Settings'),
              badge: update ? 1 : 0,
            ),
          ],
        ),
        body: IndexedStack(
          index: tab.index,
          children: const [
            HomePage(),
            TabsPage(),
            ActivityPage(),
            SettingsPage(),
          ],
        ),
      ),
    );
  }
}
