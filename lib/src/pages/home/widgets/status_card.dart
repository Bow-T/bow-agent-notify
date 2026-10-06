import 'package:flutter/material.dart';

import '../../../components/glass.dart';
import '../../../components/icon3d.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';

/// Dòng trạng thái đầu mục Hôm nay: đang nghe mấy máy, mấy tab đang chạy. Có máy chưa đăng ký nhận thông báo được
/// thì dòng chuyển đỏ và bấm vào là mở Cài đặt (nơi ghi rõ máy nào).
class StatusStrip extends StatelessWidget {
  const StatusStrip({
    super.key,
    required this.hosts,
    required this.notListening,
    required this.runningTabs,
    required this.onFix,
  });

  /// Tên các máy đã ghép.
  final List<String> hosts;

  /// Số máy mà lần đăng ký nhận thông báo gần nhất hỏng.
  final int notListening;
  final int runningTabs;

  /// Mở Cài đặt → Máy đã ghép.
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final broken = notListening > 0;
    final color = broken ? c.dangerInk : c.ok;
    return Glass(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: broken ? onFix : null,
          borderRadius: c.radius(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: broken
                          ? t(
                              'Chưa nghe được $notListening máy',
                              'Not listening to $notListening machine${notListening == 1 ? '' : 's'}',
                            )
                          : t(
                              'Đang nghe ${hosts.length} máy',
                              'Listening to ${hosts.length} machine${hosts.length == 1 ? '' : 's'}',
                            ),
                      style: TextStyle(
                        color: broken ? c.dangerInk : c.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                      children: [
                        if (broken)
                          TextSpan(
                            text: t(' · xem Cài đặt', ' · see Settings'),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          )
                        else if (hosts.length == 1 && hosts.first.isNotEmpty)
                          TextSpan(
                            text: ' · ${hosts.first}',
                            style: TextStyle(
                              color: c.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (runningTabs > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    t('$runningTabs tab chạy', '$runningTabs running'),
                    style: TextStyle(color: c.muted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cảnh báo: quyền thông báo của app đang bị tắt.
class NotifyDeniedCard extends StatelessWidget {
  const NotifyDeniedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Glass(
      tint: c.danger.withValues(alpha: 0.16),
      child: Row(
        children: [
          const Icon3d('warning', size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t(
                'Thông báo đang bị tắt cho app này — bật lại trong Cài đặt của điện thoại.',
                'Notifications are off for this app — enable them in the phone settings.',
              ),
              style: TextStyle(color: c.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mục Hôm nay lúc không có thẻ nào: nói rõ là hết việc (hoặc vì sao thẻ không bao giờ hiện ở đây).
class NothingWaitingCard extends StatelessWidget {
  const NothingWaitingCard({super.key, required this.canApprove});

  /// Có ít nhất một máy cho duyệt từ điện thoại này.
  final bool canApprove;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(
        children: [
          const Icon3d('success', size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Không có gì chờ bạn', 'Nothing is waiting for you'),
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canApprove
                      ? t(
                          'Agent cần duyệt hay hỏi gì, thẻ sẽ hiện ở đây.',
                          'When an agent needs approval or asks something, the card shows up here.',
                        )
                      : t(
                          'Máy đã ghép mới chỉ gửi thông báo. Muốn duyệt tại đây: bật "Duyệt từ điện thoại" trên web bow rồi quét lại mã.',
                          'The paired machine only sends notifications. To approve here, turn on "Approve from phone" in bow and scan the code again.',
                        ),
                  style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
