import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/glass.dart';
import '../../components/glass_button.dart';
import '../../components/icon3d.dart';
import '../../components/row_tile.dart';
import '../../components/section_title.dart';
import '../../components/sub_page.dart';
import '../../models/mirror.dart';
import '../../services/notification_service.dart';
import '../../themes/bow_theme.dart';
import '../../utils/l10n.dart';
import '../home/home_vm.dart';
import '../tabs/tabs_vm.dart';

/// Cài đặt → Chẩn đoán: trả lời "sao không thấy thông báo / không thấy thẻ / không thấy tab" ngay trên máy — thử lại
/// từng chặng của từng máy đã ghép và chỉ ra chặng nào hỏng.
class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  /// `null` = đang thử.
  List<MachineCheck>? _checks;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _checks = null);
    final checks = await ref.read(homeVmProvider.notifier).diagnose();
    if (mounted) setState(() => _checks = checks);
  }

  String _clock(DateTime at) => TimeOfDay.fromDateTime(at).format(context);

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final state = ref.watch(homeVmProvider);
    final pages = ref.watch(tabsVmProvider);
    final notifications = ref.read(notificationServiceProvider);
    final checks = _checks;
    final now = DateTime.now();

    // Một dòng kết quả: `ok` null = không áp dụng / chưa biết.
    Widget line(bool? ok, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon3d(
            ok == null
                ? 'info'
                : ok
                ? 'success'
                : 'error',
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ok == false ? c.dangerInk : c.ink,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );

    String pageLine(List<MachineTabs> mine) {
      if (mine.isEmpty) {
        return t(
          'Trang bow: chưa có trang nào báo về (chưa bật "xem tab trên điện thoại", hoặc trang đang đóng).',
          'bow page: nothing is reporting (tab viewing is off, or the page is closed).',
        );
      }
      final live = mine.where((page) => !page.stale(now)).toList();
      if (live.isEmpty) {
        return t(
          'Trang bow: im từ ${_clock(mine.first.at)} — trang đã đóng hoặc máy đã ngủ.',
          'bow page: silent since ${_clock(mine.first.at)} — closed, or the machine is asleep.',
        );
      }
      final tabs = live.fold(0, (sum, page) => sum + page.tabs.length);
      return t(
        'Trang bow: đang báo về · $tabs tab.',
        'bow page: reporting · $tabs tabs.',
      );
    }

    return SubPage(
      title: t('Chẩn đoán', 'Diagnostics'),
      children: [
        RowTile(
          icon: state.notifyDenied ? 'warning' : 'bell',
          title: t('Quyền thông báo', 'Notification permission'),
          subtitle: state.notifyDenied
              ? t(
                  'Đang bị tắt — bật lại trong Cài đặt của điện thoại. Tắt thì không thông báo nào hiện.',
                  'Turned off — enable it in the phone settings. Nothing can show while it is off.',
                )
              : t('Đang bật', 'On'),
          subtitleColor: state.notifyDenied ? c.dangerInk : null,
        ),
        SectionTitle(t('Máy đã ghép', 'Paired machines')),
        if (state.pairings.isEmpty)
          RowTile(
            icon: 'qr',
            title: t('Chưa ghép máy nào', 'Nothing paired yet'),
            subtitle: t(
              'Ghép máy trước rồi quay lại đây.',
              'Pair a machine first, then come back.',
            ),
          )
        else if (checks == null)
          Glass(
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: c.accentInk,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('Đang thử từng chặng…', 'Checking each step…'),
                    style: TextStyle(color: c.ink),
                  ),
                ),
              ],
            ),
          )
        else
          for (final check in checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Glass(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      check.pairing.host.isEmpty
                          ? check.pairing.projectId
                          : check.pairing.host,
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    line(
                      check.subscribed,
                      check.subscribed
                          ? t(
                              'Đăng ký nhận thông báo: được.',
                              'Notification subscription: OK.',
                            )
                          : t(
                              'Đăng ký nhận thông báo: hỏng — cần mạng. Thông báo của máy này sẽ không tới.',
                              'Notification subscription: failed — needs network. Nothing from this machine will arrive.',
                            ),
                    ),
                    line(check.database, switch (check.database) {
                      null => t(
                        'Thẻ chờ duyệt: máy này mới chỉ gửi thông báo. Bật "Duyệt từ điện thoại" ở web bow rồi quét lại mã.',
                        'Approval cards: this machine only sends notifications. Turn on "Approve from phone" in bow and scan again.',
                      ),
                      true => t(
                        'Thẻ chờ duyệt: đọc được.',
                        'Approval cards: readable.',
                      ),
                      false => t(
                        'Thẻ chờ duyệt: không đọc được (${check.error}).',
                        'Approval cards: cannot read (${check.error}).',
                      ),
                    }),
                    if (check.pairing.canApprove)
                      line(
                        () {
                          final mine = [
                            for (final page in pages)
                              if (page.pairing.topic == check.pairing.topic)
                                page,
                          ];
                          return mine.isEmpty
                              ? null
                              : mine.any((page) => !page.stale(now));
                        }(),
                        pageLine([
                          for (final page in pages)
                            if (page.pairing.topic == check.pairing.topic) page,
                        ]),
                      ),
                  ],
                ),
              ),
            ),
        SectionTitle(t('Thông báo gần nhất', 'Latest notification')),
        RowTile(
          icon: 'activity',
          title: state.recent.isEmpty
              ? t('Chưa nhận gì từ lúc mở app', 'Nothing since the app opened')
              : '${state.recent.first.title} · ${_clock(state.recent.first.at)}',
          subtitle: t(
            'App chỉ ghi lại thông báo tới trong lúc đang mở. Muốn thử cả đường từ máy: bấm "Gửi thử" trên web bow.',
            'Only notifications that arrive while the app is open are listed. To test the whole path, press "Send test" in bow.',
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            GlassButton(
              label: t('Thử lại', 'Check again'),
              icon: Icons.refresh_rounded,
              kind: GlassButtonKind.primary,
              onPressed: checks == null && state.pairings.isNotEmpty
                  ? null
                  : _run,
            ),
            if (notifications.canPreview)
              GlassButton(
                label: t(
                  'Thông báo thử trên máy này',
                  'Test notification here',
                ),
                onPressed: () => notifications.preview(
                  'bow_ask',
                  title: t('Thông báo thử', 'Test notification'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
