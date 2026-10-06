import 'package:flutter/material.dart';

import '../../../components/glass.dart';
import '../../../components/icon3d.dart';
import '../../../components/segmented.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';
import '../../tabs/typing_gate.dart';

/// Cài đặt → Bảo mật: thứ app luôn đòi xác thực (không tắt được — ghi ra để người dùng biết), và thời gian một lần mở
/// khoá gõ lệnh có hiệu lực.
class SecurityTile extends StatelessWidget {
  const SecurityTile({
    super.key,
    required this.unlockMinutes,
    required this.onUnlockMinutes,
  });

  final int unlockMinutes;
  final ValueChanged<int> onUnlockMinutes;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    Widget heading(
      String icon,
      String title,
      String subtitle, {
      Widget? trailing,
    }) => Row(
      children: [
        Icon3d(icon, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: c.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.35),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(
            'lock',
            t('Vân tay khi rủi ro', 'Fingerprint for risky actions'),
            t(
              'Cho phép một thao tác rủi ro và giao việc mới luôn phải qua vân tay, khuôn mặt hoặc mật mã máy.',
              'Allowing a risky action and starting a new task always need your fingerprint, face or passcode.',
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                t('Luôn bật', 'Always on'),
                style: TextStyle(
                  color: c.ok,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: c.hairline),
          const SizedBox(height: 12),
          heading(
            'hourglass',
            t('Giữ mở khoá gõ lệnh', 'Keep typing unlocked'),
            t(
              'Gõ cho agent: xác thực một lần rồi gõ tiếp trong ngần này. App ra nền là khoá lại ngay.',
              'Typing to the agent: authenticate once, then keep typing this long. Leaving the app locks it.',
            ),
          ),
          const SizedBox(height: 10),
          Segmented<int>(
            value: unlockMinutes,
            onChanged: onUnlockMinutes,
            options: [
              for (final minutes in UnlockMinutes.choices)
                (minutes, t('$minutes phút', '$minutes min')),
            ],
          ),
        ],
      ),
    );
  }
}
