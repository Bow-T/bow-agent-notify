import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/glass.dart';
import '../../components/glass_button.dart';
import '../../components/row_tile.dart';
import '../../components/sub_page.dart';
import '../../services/notification_service.dart';
import '../../themes/bow_theme.dart';
import '../../utils/l10n.dart';

/// Cài đặt → Âm báo: ba loại thông báo, mỗi loại một âm riêng. Android nghe thử được từng âm (app dựng một thông báo
/// mẫu trên đúng kênh của loại đó); tắt / đổi âm từng loại là việc của cài đặt hệ thống — Android khoá âm theo kênh.
class SoundsPage extends ConsumerWidget {
  const SoundsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Bow.of(context);
    final notifications = ref.read(notificationServiceProvider);
    final kinds = [
      (
        channel: 'bow_ask',
        icon: 'shield',
        title: t('Chờ bạn', 'Waiting for you'),
        note: t(
          'Agent xin duyệt, đang hỏi, hoặc gửi thử — âm đi lên, bỏ lửng.',
          'An agent asks for approval, asks a question, or a test — a rising, open sound.',
        ),
      ),
      (
        channel: 'bow_done',
        icon: 'success',
        title: t('Đã xong', 'Finished'),
        note: t(
          'Lượt chạy xong — hợp âm rải lên rồi đậu lại.',
          'A run finished — a chord that climbs and settles.',
        ),
      ),
      (
        channel: 'bow_fail',
        icon: 'error',
        title: t('Lỗi', 'Failed'),
        note: t(
          'Lượt chạy lỗi — âm đi xuống, trầm.',
          'A run failed — a low, falling sound.',
        ),
      ),
    ];
    return SubPage(
      title: t('Âm báo', 'Sounds'),
      children: [
        for (final kind in kinds)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RowTile(
              icon: kind.icon,
              title: kind.title,
              subtitle: kind.note,
              trailing: notifications.canPreview
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GlassButton(
                        label: t('Nghe thử', 'Play'),
                        onPressed: () => notifications.preview(
                          kind.channel,
                          title: kind.title,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        const SizedBox(height: 4),
        Glass(
          child: Text(
            notifications.canPreview
                ? t(
                    'Tắt hoặc đổi âm của từng loại: Cài đặt của máy → Thông báo → Bow Notify — mỗi loại là một kênh riêng. Nghe thử không kêu khi máy đang ở chế độ im lặng.',
                    'To mute or change one kind: phone Settings → Notifications → Bow Notify — each kind is its own channel. The sample is silent while the phone is muted.',
                  )
                : t(
                    'Trên iPhone, thông báo do hệ điều hành hiện và phát âm — tắt hoặc đổi trong Cài đặt → Thông báo → Bow Notify.',
                    'On iPhone the system shows and plays notifications — mute or change them in Settings → Notifications → Bow Notify.',
                  ),
            style: TextStyle(color: c.muted, fontSize: 13, height: 1.45),
          ),
        ),
      ],
    );
  }
}
