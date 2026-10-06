import 'package:flutter/material.dart';

import '../../../components/glass.dart';
import '../../../components/glass_button.dart';
import '../../../components/icon3d.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';

/// Mời ghim widget ra màn hình chính — khỏi phải tự tìm trong bảng chọn widget của máy. Hai loại: thẻ "Chờ bạn duyệt"
/// (lệnh + nút) và viên thuốc "Trạng thái".
class PinWidgetTile extends StatelessWidget {
  const PinWidgetTile({super.key, required this.onPin});

  /// `status` = ghim viên thuốc trạng thái (không thì ghim thẻ chờ duyệt).
  final void Function(bool status) onPin;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon3d('bolt', size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t(
                    'Widget: thấy việc đang chờ và duyệt ngay ngoài màn hình chính.',
                    'Widget: see what is waiting and approve right on the home screen.',
                  ),
                  style: TextStyle(color: c.ink, fontSize: 13.5, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlassButton(
                label: t('Thêm thẻ chờ duyệt', 'Add approval card'),
                kind: GlassButtonKind.primary,
                onPressed: () => onPin(false),
              ),
              GlassButton(
                label: t('Thêm viên trạng thái', 'Add status pill'),
                onPressed: () => onPin(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
