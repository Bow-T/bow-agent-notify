import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/glass.dart';
import '../../../components/icon3d.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';
import '../../settings/update_vm.dart';
import '../../settings/widgets/update_tile.dart';

/// Dải báo "đã có bản mới" ở đầu mục Hôm nay: cập nhật ngay tại đây (cùng nút với Cài đặt → Về ứng dụng), hoặc gạt
/// đi tới lần mở app sau. Không có bản mới / đã gạt thì không chiếm chỗ.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateVmProvider);
    if (!state.offer || state.hidden) return const SizedBox.shrink();
    final c = Bow.of(context);
    final busy = state.phase != UpdatePhase.available;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        tint: c.accent.withValues(alpha: c.isBrutal ? 0.35 : 0.14),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon3d('magic', size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(
                          'Bow Notify ${state.release!.version}',
                          'Bow Notify ${state.release!.version}',
                        ),
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        updateStatus(state) ?? '',
                        style: TextStyle(
                          color: state.problem != null ? c.dangerInk : c.muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const UpdateButton(),
                // Đang tải / đang cài thì không gạt được — gạt đi là mất chỗ xem tiến độ.
                IconButton(
                  onPressed: busy
                      ? null
                      : ref.read(updateVmProvider.notifier).hide,
                  tooltip: t('Để sau', 'Later'),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: busy ? c.muted.withValues(alpha: 0.35) : c.muted,
                  ),
                ),
              ],
            ),
            if (state.phase == UpdatePhase.downloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 8, 2),
                child: UpdateProgress(state.progress),
              ),
          ],
        ),
      ),
    );
  }
}
