import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/bow_scaffold.dart';
import '../../components/glass_button.dart';
import '../../components/glass_dialog.dart';
import '../../components/recent_list.dart';
import '../../components/section_title.dart';
import '../../models/pending_card.dart';
import '../../utils/l10n.dart';
import '../shell/pair_actions.dart';
import '../shell/shell_vm.dart';
import '../tabs/tabs_vm.dart';
import 'home_vm.dart';
import 'widgets/onboarding_card.dart';
import 'widgets/pending_card_view.dart';
import 'widgets/status_card.dart';
import 'widgets/update_banner.dart';

/// Mục "Hôm nay" (View): chỉ thứ đang cần người dùng — thẻ chờ duyệt, câu agent hỏi, và vài thông báo vừa tới. Chưa
/// ghép máy nào thì là màn hướng dẫn ghép. Nó chỉ vẽ `HomeState` và chuyển thao tác cho `HomeVm`.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  /// Số thông báo vừa nhận hiện ở đây; còn lại xem ở mục Hoạt động.
  static const _recentShown = 3;

  /// Hộp xác nhận cho thao tác rủi ro trên máy KHÔNG có vân tay / khoá màn hình (ViewModel gọi khi cần).
  Future<bool> _askRisky(BuildContext context, PendingCard card) async {
    if (!context.mounted) return false;
    final ok = await showGlassDialog<bool>(
      context,
      title: t('Cho phép thao tác rủi ro?', 'Allow a risky action?'),
      content: Text(card.text, maxLines: 8, overflow: TextOverflow.ellipsis),
      actions: (close) => [
        GlassButton(label: t('Thôi', 'Cancel'), onPressed: () => close(false)),
        GlassButton(
          label: t('Cho phép', 'Allow'),
          kind: GlassButtonKind.danger,
          onPressed: () => close(true),
        ),
      ],
    );
    return ok == true;
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    PendingCard card,
    Map<String, Object?> reply,
  ) async {
    final result = await ref
        .read(homeVmProvider.notifier)
        .decide(card, reply, askRisky: () => _askRisky(context, card));
    if (context.mounted) say(context, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeVmProvider);
    final shell = ref.read(shellVmProvider.notifier);
    if (state.pairings.isEmpty) {
      return ListView(
        padding: BowScaffold.listPadding(nav: true),
        children: [
          const UpdateBanner(),
          OnboardingCard(
            busy: state.busy,
            onScan: () => scanAndPair(context, ref),
            onPaste: () => pasteAndPair(context, ref),
          ),
          SectionTitle(t('Ba bước', 'Three steps')),
          const PairingSteps(),
        ],
      );
    }
    final running = ref
        .watch(tabsVmProvider)
        .expand((machine) => machine.tabs)
        .where((tab) => tab.running)
        .length;
    return ListView(
      padding: BowScaffold.listPadding(nav: true),
      children: [
        const UpdateBanner(),
        StatusStrip(
          hosts: [for (final pairing in state.pairings) pairing.host],
          notListening: state.notListening.length,
          runningTabs: running,
          onFix: () => shell.open(ShellTab.settings),
        ),
        if (state.notifyDenied) ...[
          const SizedBox(height: 10),
          const NotifyDeniedCard(),
        ],
        if (state.pending.isEmpty) ...[
          const SizedBox(height: 12),
          NothingWaitingCard(
            canApprove: state.pairings.any((pairing) => pairing.canApprove),
          ),
        ] else ...[
          SectionTitle(
            t(
              'Chờ bạn duyệt · ${state.pending.length}',
              'Waiting for you · ${state.pending.length}',
            ),
          ),
          for (final card in state.pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PendingCardView(
                key: ValueKey(card.id),
                card: card,
                busy: state.sending.contains(card.id),
                onDecide: (reply) => _decide(context, ref, card, reply),
              ),
            ),
        ],
        if (state.recent.isNotEmpty) ...[
          SectionTitle(
            t('Vừa nhận', 'Just received'),
            action: state.recent.length > _recentShown
                ? t('Xem tất cả ›', 'See all ›')
                : null,
            onAction: () => shell.open(ShellTab.activity),
          ),
          RecentList(items: state.recent.take(_recentShown).toList()),
        ],
      ],
    );
  }
}
