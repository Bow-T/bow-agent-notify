import 'package:flutter/material.dart';

import '../../../components/glass.dart';
import '../../../components/glass_button.dart';
import '../../../components/listening_mark.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';

/// Lần đầu mở app (chưa ghép máy nào): nút quét to nằm giữa màn — người mới không phải đoán icon nhỏ ở thanh trên —
/// kèm lối dán mã cho lúc không quét được.
class OnboardingCard extends StatelessWidget {
  const OnboardingCard({
    super.key,
    required this.busy,
    required this.onScan,
    required this.onPaste,
  });

  /// Đang ghép một máy (khoá nút).
  final bool busy;
  final VoidCallback onScan;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Glass(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        children: [
          const ListeningMark(active: false),
          Text(
            t('Chưa ghép máy nào', 'Nothing paired yet'),
            style: TextStyle(
              color: c.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t(
              'Ghép với máy đang chạy bow để nhận thông báo và duyệt từ điện thoại.',
              'Pair with the machine running bow to get notifications and approve from your phone.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: busy
                  ? t('Đang ghép…', 'Pairing…')
                  : t('Quét mã ghép', 'Scan pairing code'),
              // Icon phẳng màu trắng, không phải 3D: hình 3D có màu riêng nên chìm trên nền lam của nút.
              icon: Icons.qr_code_scanner_rounded,
              kind: GlassButtonKind.primary,
              large: true,
              onPressed: busy ? null : onScan,
            ),
          ),
          TextButton(
            onPressed: busy ? null : onPaste,
            child: Text(
              t(
                'Không quét được? Dán mã ghép',
                'Cannot scan? Paste the pairing code',
              ),
              style: TextStyle(
                color: c.accentInk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: c.isBrutal ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ba bước ghép máy, ngay dưới thẻ lần đầu.
class PairingSteps extends StatelessWidget {
  const PairingSteps({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final steps = [
      t(
        'Trên web bow mở Cài đặt → Thông báo điện thoại.',
        'In bow open Settings → Phone notifications.',
      ),
      t(
        'Bấm Quét mã ghép ở trên, đưa camera vào mã QR.',
        'Press Scan pairing code above and point at the QR code.',
      ),
      t(
        'Bấm Gửi thử trên web — điện thoại rung là xong.',
        'Press Send test in bow — your phone buzzes and you are done.',
      ),
    ];
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        children: [
          for (final (index, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: c.isBrutal
                        ? BoxDecoration(
                            color: c.accent,
                            border: Border.all(color: c.ink, width: c.line),
                          )
                        : BoxDecoration(
                            color: c.accent,
                            shape: BoxShape.circle,
                          ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: c.onAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        step,
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
