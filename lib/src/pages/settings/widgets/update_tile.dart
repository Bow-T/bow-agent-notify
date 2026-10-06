import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/glass.dart';
import '../../../components/glass_button.dart';
import '../../../components/icon3d.dart';
import '../../../components/markdown_text.dart';
import '../../../components/segmented.dart';
import '../../../constants/version.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';
import '../update_vm.dart';

/// Dòng trạng thái của việc cập nhật (`null` = chưa hỏi lần nào). Lỗi vừa gặp đứng trước bước đang ở.
String? updateStatus(UpdateState state) {
  final version = state.release?.version;
  final percent = (state.progress * 100).round();
  return switch (state.problem) {
    UpdateProblem.check => t(
      'không kiểm tra được (cần mạng)',
      'could not check (needs network)',
    ),
    UpdateProblem.download => t(
      'tải bản $version hỏng — thử lại',
      'downloading $version failed — try again',
    ),
    UpdateProblem.conflict => t(
      'bản $version ký bằng khoá khác bản đang cài — gỡ app rồi cài lại từ link tải',
      'version $version is signed with a different key — uninstall, then install from the download link',
    ),
    UpdateProblem.storage => t(
      'máy không đủ chỗ trống để cài',
      'not enough free space to install',
    ),
    UpdateProblem.install => [
      t('không cài được bản $version', 'could not install $version'),
      if (state.detail case final detail?) '($detail)',
    ].join(' '),
    null => switch (state.phase) {
      UpdatePhase.idle => null,
      UpdatePhase.checking => t('đang kiểm tra…', 'checking…'),
      UpdatePhase.current => t('đang là bản mới nhất', 'this is the latest'),
      UpdatePhase.available => t(
        'đã có bản $version',
        'version $version is available',
      ),
      UpdatePhase.downloading => t(
        'đang tải bản $version · $percent%',
        'downloading $version · $percent%',
      ),
      UpdatePhase.ready => t(
        'đã tải bản $version — bấm Cài ngay',
        '$version downloaded — press Install',
      ),
      // Cài đè lên chính mình: Android tắt app để thay bản mới — nói trước, kẻo tưởng app tự thoát vì lỗi.
      UpdatePhase.installing => t(
        'xác nhận ở hộp của máy — cài xong app tự đóng, mở lại là bản mới',
        'confirm in the system dialog — the app closes when done; reopen it for the new version',
      ),
    },
  };
}

/// Mở trang tải bằng trình duyệt; máy không mở được thì hiện link để người dùng tự chép.
Future<void> openUpdateLink(BuildContext context, WidgetRef ref) async {
  final vm = ref.read(updateVmProvider.notifier);
  final link = vm.downloadLink;
  final opened = await vm.openDownloadLink();
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          t(
            'Không mở được trình duyệt. Link tải: $link',
            'Could not open the browser. Download link: $link',
          ),
        ),
      ),
    );
}

/// Nút của việc cập nhật, đổi theo bước: Kiểm tra → Cập nhật (tải rồi mở trình cài đặt) → phần trăm đang tải → Cài
/// ngay. Máy không cài được trong app (iPhone) thì là "Tải về" — mở trang phát hành. Dùng ở Cài đặt và ở dải báo của
/// Hôm nay; cả hai cùng đọc một `UpdateVm` nên bấm ở đâu thì chỗ kia cũng đổi theo.
class UpdateButton extends ConsumerWidget {
  const UpdateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateVmProvider);
    final vm = ref.read(updateVmProvider.notifier);
    return switch (state.phase) {
      UpdatePhase.available when !state.inApp => GlassButton(
        label: t('Tải về', 'Download'),
        kind: GlassButtonKind.primary,
        onPressed: () => openUpdateLink(context, ref),
      ),
      UpdatePhase.available => GlassButton(
        label: t('Cập nhật', 'Update'),
        kind: GlassButtonKind.primary,
        onPressed: vm.update,
      ),
      UpdatePhase.downloading => GlassButton(
        label: '${(state.progress * 100).round()}%',
        onPressed: null,
      ),
      UpdatePhase.ready || UpdatePhase.installing => GlassButton(
        label: t('Cài ngay', 'Install'),
        kind: GlassButtonKind.primary,
        onPressed: vm.update,
      ),
      UpdatePhase.idle ||
      UpdatePhase.checking ||
      UpdatePhase.current => GlassButton(
        label: t('Kiểm tra', 'Check'),
        onPressed: state.phase == UpdatePhase.checking ? null : vm.check,
      ),
    };
  }
}

/// Thanh tiến độ tải, vẽ theo theme (kính: rãnh bo tròn; brutal: khối viền mực).
class UpdateProgress extends StatelessWidget {
  const UpdateProgress(this.value, {super.key});

  final double value;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Container(
      height: c.isBrutal ? 10 : 6,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.well,
        borderRadius: c.radius(3),
        border: c.isBrutal ? Border.all(color: c.ink, width: c.line) : null,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0, 1).toDouble(),
        child: ColoredBox(color: c.accent),
      ),
    );
  }
}

/// Cài đặt → Về ứng dụng: phiên bản đang cài, bản mới (kiểm tra → tải → cài ngay trong app, kèm ghi chú "có gì
/// mới"), và công tắc tự kiểm tra khi mở app.
class UpdateTile extends ConsumerWidget {
  const UpdateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Bow.of(context);
    final state = ref.watch(updateVmProvider);
    final vm = ref.read(updateVmProvider.notifier);
    final version = t('Phiên bản $appVersion', 'Version $appVersion');
    final status = updateStatus(state);
    final notes = state.offer ? state.release?.notes ?? '' : '';
    // Cập nhật trong app vừa hỏng (không phải lỗi "không kiểm tra được"): mời tải bằng trình duyệt như trước.
    final fallback =
        state.inApp &&
        state.problem != null &&
        state.problem != UpdateProblem.check;
    Text small(String text, {Color? color, FontWeight? weight}) => Text(
      text,
      style: TextStyle(
        color: color ?? c.muted,
        fontSize: 12.5,
        height: 1.35,
        fontWeight: weight,
      ),
    );
    Text title(String text) => Text(
      text,
      style: TextStyle(color: c.ink, fontSize: 15, fontWeight: FontWeight.w600),
    );
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon3d('info', size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title('Bow Notify'),
                    small(
                      status == null ? version : '$version · $status',
                      color: state.problem != null
                          ? c.dangerInk
                          : state.offer
                          ? c.accentInk
                          : null,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: UpdateButton(),
              ),
            ],
          ),
          if (state.phase == UpdatePhase.downloading) ...[
            const SizedBox(height: 12),
            UpdateProgress(state.progress),
          ],
          if (fallback)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => openUpdateLink(context, ref),
                child: Text(
                  t('Tải bằng trình duyệt ›', 'Download in the browser ›'),
                  style: TextStyle(
                    color: c.accentInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            small(
              t(
                'Có gì mới ở bản ${state.release!.version}',
                'What is new in ${state.release!.version}',
              ),
              color: c.ink,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: 4),
            MarkdownText(notes),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: c.hairline),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon3d('hourglass', size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title(t('Tự kiểm tra bản mới', 'Check for updates')),
                    small(
                      t(
                        'Mỗi lần mở app hỏi GitHub một lần. Có bản mới thì báo ở Hôm nay — tải và cài chỉ khi bạn bấm.',
                        'Asks GitHub once each time the app opens. A new version shows up in Today — it downloads and installs only when you press.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Segmented<bool>(
              value: state.auto,
              onChanged: vm.setAuto,
              options: [
                (true, t('Tự kiểm tra', 'Automatic')),
                (false, t('Chỉ khi bấm', 'Only when I press')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
