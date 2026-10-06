import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/bow_scaffold.dart';
import '../../components/glass_button.dart';
import '../../components/glass_dialog.dart';
import '../../components/row_tile.dart';
import '../../components/section_title.dart';
import '../../constants/version.dart';
import '../../models/pairing.dart';
import '../../themes/bow_theme.dart';
import '../../utils/l10n.dart';
import '../home/home_vm.dart';
import '../shell/pair_actions.dart';
import 'widgets/machine_tile.dart';
import 'widgets/pin_widget_tile.dart';

/// Mục "Cài đặt": máy đã ghép, quyền thông báo, widget màn hình chính, phiên bản. Dùng chung `HomeVm` — máy đã ghép
/// và quyền thông báo là trạng thái của cả app chứ không riêng màn này.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _unpair(
    BuildContext context,
    WidgetRef ref,
    Pairing pairing,
  ) async {
    final ok = await showGlassDialog<bool>(
      context,
      title: t('Bỏ ghép ${pairing.host}?', 'Unpair ${pairing.host}?'),
      content: Text(
        t(
          'Điện thoại này thôi nhận thông báo từ máy đó.',
          'This phone stops receiving notifications from it.',
        ),
      ),
      actions: (close) => [
        GlassButton(label: t('Thôi', 'Cancel'), onPressed: () => close(false)),
        GlassButton(
          label: t('Bỏ ghép', 'Unpair'),
          kind: GlassButtonKind.danger,
          onPressed: () => close(true),
        ),
      ],
    );
    if (ok != true) return;
    final result = await ref.read(homeVmProvider.notifier).unpair(pairing);
    if (context.mounted) say(context, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Bow.of(context);
    final state = ref.watch(homeVmProvider);
    final vm = ref.read(homeVmProvider.notifier);
    final paired = state.pairings.isNotEmpty;
    return ListView(
      padding: BowScaffold.listPadding(nav: true),
      children: [
        SectionTitle(t('Máy đã ghép', 'Paired machines')),
        for (final pairing in state.pairings)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MachineTile(
              pairing: pairing,
              listening: !state.notListening.contains(pairing.topic),
              onUnpair: () => _unpair(context, ref, pairing),
            ),
          ),
        RowTile(
          icon: 'qr',
          title: paired
              ? t('Ghép máy khác', 'Pair another machine')
              : t('Ghép máy', 'Pair a machine'),
          subtitle: t(
            'Quét mã QR ở web bow: Cài đặt → Thông báo điện thoại',
            'Scan the QR code in bow: Settings → Phone notifications',
          ),
          onTap: state.busy ? null : () => scanAndPair(context, ref),
        ),
        SectionTitle(t('Thông báo', 'Notifications')),
        RowTile(
          icon: 'bell',
          title: t('Thông báo của app', 'App notifications'),
          subtitle: state.notifyDenied
              ? t(
                  'Đang bị tắt — bật lại trong Cài đặt của điện thoại.',
                  'Turned off — enable them in the phone settings.',
                )
              : t('Đang bật', 'On'),
          subtitleColor: state.notifyDenied ? c.danger : null,
        ),
        if (state.canPinWidget && paired) ...[
          SectionTitle(t('Màn hình chính', 'Home screen')),
          PinWidgetTile(onPin: (status) => vm.pinWidget(status: status)),
        ],
        SectionTitle(t('Về ứng dụng', 'About')),
        RowTile(
          icon: 'info',
          title: 'Bow Notify',
          subtitle: t('Phiên bản $appVersion', 'Version $appVersion'),
        ),
      ],
    );
  }
}
