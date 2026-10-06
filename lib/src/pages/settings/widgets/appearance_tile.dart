import 'package:flutter/material.dart';

import '../../../components/glass.dart';
import '../../../components/icon3d.dart';
import '../../../components/segmented.dart';
import '../../../models/appearance.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';

/// Cài đặt → Giao diện: chọn phong cách (hai theme của web bow), chế độ màu (chỉ với kính) và ngôn ngữ.
class AppearanceTile extends StatelessWidget {
  const AppearanceTile({
    super.key,
    required this.appearance,
    required this.onStyle,
    required this.onMode,
    required this.onLanguage,
  });

  final Appearance appearance;
  final ValueChanged<BowStyle> onStyle;
  final ValueChanged<GlassMode> onMode;
  final ValueChanged<AppLanguage> onLanguage;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    Widget heading(String icon, String title, String subtitle) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
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
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon của nút đổi theme trên web: giọt nước = kính, viên gạch = brutal.
          heading(
            c.isBrutal ? 'brick' : 'drop',
            t('Phong cách', 'Style'),
            t(
              'Hai theme của web bow: kính mờ, hoặc khối viền đậm.',
              'The two bow themes: frosted glass, or bold outlined blocks.',
            ),
          ),
          Segmented<BowStyle>(
            value: appearance.style,
            onChanged: onStyle,
            options: [
              (BowStyle.glass, t('Kính', 'Glass')),
              (BowStyle.brutal, 'Brutal'),
            ],
          ),
          // Brutal chỉ có một bản sáng.
          if (appearance.style == BowStyle.glass) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: c.hairline),
            const SizedBox(height: 12),
            heading(
              'lamp',
              t('Chế độ màu', 'Colour mode'),
              t(
                'Sáng, tối, hoặc theo cài đặt của máy.',
                'Light, dark, or follow the phone setting.',
              ),
            ),
            Segmented<GlassMode>(
              value: appearance.mode,
              onChanged: onMode,
              options: [
                (GlassMode.system, t('Theo máy', 'System')),
                (GlassMode.light, t('Sáng', 'Light')),
                (GlassMode.dark, t('Tối', 'Dark')),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: c.hairline),
          const SizedBox(height: 12),
          heading(
            'globe',
            t('Ngôn ngữ', 'Language'),
            t(
              'Chữ trong app, trên thông báo và widget.',
              'Text in the app, on notifications and the widget.',
            ),
          ),
          // Tên từng ngôn ngữ viết bằng chính nó — đang ở tiếng nào cũng đọc ra.
          Segmented<AppLanguage>(
            value: appearance.language,
            onChanged: onLanguage,
            options: [
              (AppLanguage.system, t('Theo máy', 'System')),
              (AppLanguage.vi, 'Tiếng Việt'),
              (AppLanguage.en, 'English'),
            ],
          ),
        ],
      ),
    );
  }
}
