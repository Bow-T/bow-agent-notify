import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/bow_scaffold.dart';
import '../../components/glass_button.dart';
import '../../components/glass_dialog.dart';
import '../../components/icon3d.dart';
import '../../components/section_title.dart';
import '../../models/pairing.dart';
import '../../models/pending_card.dart';
import '../../utils/l10n.dart';
import '../scan/scan_page.dart';
import 'home_vm.dart';
import '../tabs/tab_page.dart';
import '../tabs/tabs_vm.dart';
import '../tabs/typing_gate.dart';
import 'widgets/machine_tabs_section.dart';
import 'widgets/machine_tile.dart';
import 'widgets/pending_card_view.dart';
import 'widgets/pin_widget_tile.dart';
import 'widgets/recent_list.dart';
import 'widgets/status_card.dart';

/// Màn chính (View): chỉ vẽ `HomeState` và chuyển thao tác của người dùng cho `HomeVm`. Thứ duy nhất nó tự làm là
/// những việc cần `BuildContext` — hộp thoại, chuyển màn, thanh báo.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  HomeVm get _vm => ref.read(homeVmProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final tabs = ref.read(tabsVmProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      _vm.resumed();
      tabs.resumed();
    } else {
      _vm.paused();
      tabs.paused();
      // App ra nền: khoá lại quyền gõ lệnh (lần sau phải qua vân tay).
      ref.read(typingGateProvider.notifier).lock();
    }
  }

  /// Hiện câu ViewModel trả về (`null` = không có gì để nói).
  void _say(String? text) {
    if (text == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pair(String? raw) async => _say(await _vm.pair(raw));

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScanPage(
          title: t('Quét mã ghép', 'Scan pairing code'),
          hint: t(
            'Đưa camera vào mã QR ở web bow: Cài đặt → Thông báo điện thoại.',
            'Point at the QR code in bow: Settings → Phone notifications.',
          ),
        ),
      ),
    );
    await _pair(raw);
  }

  /// Nhập mã ghép bằng tay (web bow → "Chép mã"): dùng khi không quét được, vd mở web bow trên chính điện thoại này.
  /// Ô nhập thường chứ không tự đọc clipboard — iOS hỏi quyền mỗi lần app tự đọc.
  Future<void> _enterCode() async {
    final input = TextEditingController();
    final raw = await showGlassDialog<String>(
      context,
      title: t('Dán mã ghép', 'Paste pairing code'),
      content: TextField(
        controller: input,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        maxLines: 3,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(hintText: 'bowpush://pair?…'),
      ),
      actions: (close) => [
        GlassButton(label: t('Thôi', 'Cancel'), onPressed: () => close(null)),
        GlassButton(
          label: t('Ghép', 'Pair'),
          kind: GlassButtonKind.primary,
          onPressed: () => close(input.text),
        ),
      ],
    );
    await _pair(raw);
  }

  Future<void> _unpair(Pairing pairing) async {
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
    if (ok == true) _say(await _vm.unpair(pairing));
  }

  /// Hộp xác nhận cho thao tác rủi ro trên máy KHÔNG có vân tay / khoá màn hình (ViewModel gọi khi cần).
  Future<bool> _askRisky(PendingCard card) async {
    if (!mounted) return false;
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

  Future<void> _decide(PendingCard card, Map<String, Object?> reply) async =>
      _say(await _vm.decide(card, reply, askRisky: () => _askRisky(card)));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeVmProvider);
    final paired = state.pairings.isNotEmpty;
    // Thanh tab của các trang bow đang mở trên máy (chỉ xem) — rỗng khi máy chưa bật tính năng đó.
    final machines = [
      for (final machine in ref.watch(tabsVmProvider))
        if (machine.tabs.isNotEmpty) machine,
    ];
    return BowScaffold(
      action: IconButton(
        onPressed: state.busy ? null : _enterCode,
        tooltip: t('Dán mã ghép', 'Paste pairing code'),
        icon: const Icon3d('clipboard', size: 28),
      ),
      bottom: SizedBox(
        width: double.infinity,
        child: GlassButton(
          label: state.busy
              ? t('Đang ghép…', 'Pairing…')
              : t('Quét mã ghép', 'Scan pairing code'),
          // Icon phẳng màu trắng, không phải 3D: hình 3D có màu riêng nên chìm trên nền lam của nút (luật của bộ icon web).
          icon: Icons.qr_code_scanner_rounded,
          kind: GlassButtonKind.primary,
          large: true,
          onPressed: state.busy ? null : _scan,
        ),
      ),
      children: [
        StatusCard(
          machines: state.pairings.length,
          active: paired && !state.notifyDenied,
        ),
        if (state.notifyDenied) ...[
          const SizedBox(height: 12),
          const NotifyDeniedCard(),
        ],
        if (state.pending.isNotEmpty) ...[
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
                onDecide: (reply) => _decide(card, reply),
              ),
            ),
        ],
        for (final machine in machines)
          MachineTabsSection(
            machine: machine,
            showHost: machines.length > 1,
            onOpen: (tab) => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => TabPage(
                  tab: (
                    topic: machine.pairing.topic,
                    port: machine.port,
                    tabId: tab.id,
                  ),
                ),
              ),
            ),
          ),
        if (paired) ...[
          SectionTitle(t('Máy đã ghép', 'Paired machines')),
          for (final pairing in state.pairings)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MachineTile(
                pairing: pairing,
                listening: !state.notListening.contains(pairing.topic),
                onUnpair: () => _unpair(pairing),
              ),
            ),
        ],
        if (state.canPinWidget && paired) ...[
          SectionTitle(t('Màn hình chính', 'Home screen')),
          PinWidgetTile(onPin: (status) => _vm.pinWidget(status: status)),
        ],
        if (state.recent.isNotEmpty) ...[
          SectionTitle(t('Vừa nhận', 'Just received')),
          RecentList(items: state.recent),
        ],
      ],
    );
  }
}
