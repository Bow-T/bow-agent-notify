import 'package:flutter/material.dart';

import '../../../components/glass.dart';
import '../../../components/glass_button.dart';
import '../../../components/icon3d.dart';
import '../../../components/listening_mark.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';

/// Tấm đầu màn hình: đang nghe mấy máy (logo có vòng sóng khi đang nghe), hoặc hướng dẫn ghép máy đầu tiên.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.machines,
    required this.active,
    required this.onScan,
    this.busy = false,
  });

  /// Số máy đã ghép.
  final int machines;

  /// Đang thật sự nghe được (có máy và quyền thông báo chưa bị tắt).
  final bool active;

  /// Mở màn quét mã. Chỉ hiện thành nút khi CHƯA ghép máy nào — đã có máy thì nút quét nhỏ ở thanh trên là đủ.
  final VoidCallback onScan;

  /// Đang ghép một máy (khoá nút).
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final paired = machines > 0;
    return Glass(
      padding: const EdgeInsets.fromLTRB(12, 14, 18, 14),
      child: Row(
        children: [
          ListeningMark(active: active),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paired
                      ? t(
                          'Đang nghe $machines máy',
                          'Listening to $machines machine${machines == 1 ? '' : 's'}',
                        )
                      : t('Chưa ghép máy nào', 'Nothing paired yet'),
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paired
                      ? t(
                          'Agent chờ bạn duyệt, hỏi bạn, chạy xong hay lỗi — điện thoại báo ngay, mỗi việc một âm riêng.',
                          'Agent waiting, asking, finished or failed — your phone tells you, each with its own sound.',
                        )
                      : t(
                          'Trên web bow mở Cài đặt → Thông báo điện thoại rồi quét mã QR ở đó.',
                          'In bow open Settings → Phone notifications and scan the QR code there.',
                        ),
                  style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4),
                ),
                if (!paired) ...[
                  const SizedBox(height: 12),
                  GlassButton(
                    label: busy
                        ? t('Đang ghép…', 'Pairing…')
                        : t('Quét mã ghép', 'Scan pairing code'),
                    // Icon phẳng màu trắng, không phải 3D: hình 3D có màu riêng nên chìm trên nền lam của nút.
                    icon: Icons.qr_code_scanner_rounded,
                    kind: GlassButtonKind.primary,
                    onPressed: busy ? null : onScan,
                  ),
                ],
              ],
            ),
          ),
        ],
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
