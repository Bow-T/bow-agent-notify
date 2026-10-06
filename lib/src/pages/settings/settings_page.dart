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
import '../tabs/typing_gate.dart';
import 'appearance_vm.dart';
import 'diagnostics_page.dart';
import 'guide_page.dart';
import 'sounds_page.dart';
import 'widgets/appearance_tile.dart';
import 'widgets/machine_tile.dart';
import 'widgets/pin_widget_tile.dart';
import 'widgets/security_tile.dart';
import 'widgets/update_tile.dart';

/// Mục "Cài đặt": máy đã ghép, thông báo + âm báo, bảo mật, widget màn hình chính, giao diện, và về ứng dụng (bản mới,
/// chẩn đoán, hướng dẫn, giấy phép). Dùng chung `HomeVm` — máy đã ghép và quyền thông báo là trạng thái của cả app chứ
/// không riêng màn này.
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

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Bow.of(context);
    final state = ref.watch(homeVmProvider);
    final vm = ref.read(homeVmProvider.notifier);
    final paired = state.pairings.isNotEmpty;
    return ListView(
      // Đổi ngôn ngữ dựng lại cả cây widget — khoá này giữ chỗ đang cuộn, không thì bấm xong bị nhảy về đầu trang.
      key: const PageStorageKey('settings'),
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
          subtitleColor: state.notifyDenied ? c.dangerInk : null,
        ),
        const SizedBox(height: 10),
        RowTile(
          icon: 'magic',
          title: t('Âm báo', 'Sounds'),
          subtitle: t(
            'Chờ bạn · Đã xong · Lỗi — mỗi loại một âm',
            'Waiting · Finished · Failed — one sound each',
          ),
          onTap: () => _open(context, const SoundsPage()),
        ),
        SectionTitle(t('Bảo mật', 'Security')),
        SecurityTile(
          unlockMinutes: ref.watch(unlockMinutesProvider),
          onUnlockMinutes: ref.read(unlockMinutesProvider.notifier).set,
        ),
        if (state.canPinWidget && paired) ...[
          SectionTitle(t('Màn hình chính', 'Home screen')),
          PinWidgetTile(onPin: (status) => vm.pinWidget(status: status)),
        ],
        SectionTitle(t('Giao diện', 'Appearance')),
        AppearanceTile(
          appearance: ref.watch(appearanceVmProvider),
          onStyle: ref.read(appearanceVmProvider.notifier).setStyle,
          onMode: ref.read(appearanceVmProvider.notifier).setMode,
          onLanguage: ref.read(appearanceVmProvider.notifier).setLanguage,
        ),
        SectionTitle(t('Về ứng dụng', 'About')),
        const UpdateTile(),
        const SizedBox(height: 10),
        RowTile(
          icon: 'bug',
          title: t('Chẩn đoán', 'Diagnostics'),
          subtitle: t(
            'Không thấy thông báo, thẻ hay tab? Thử lại từng chặng.',
            'No notifications, cards or tabs? Retry each step.',
          ),
          onTap: () => _open(context, const DiagnosticsPage()),
        ),
        const SizedBox(height: 10),
        RowTile(
          icon: 'book',
          title: t('Hướng dẫn', 'Guide'),
          onTap: () => _open(context, const GuidePage()),
        ),
        const SizedBox(height: 10),
        // Phông chữ của theme brutal (và các gói app dùng) có giấy phép đòi kèm nguyên văn khi phát hành.
        RowTile(
          icon: 'layers',
          title: t('Giấy phép mã nguồn mở', 'Open-source licences'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Bow Notify',
            applicationVersion: appVersion,
          ),
        ),
      ],
    );
  }
}
