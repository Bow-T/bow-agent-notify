import 'package:flutter/material.dart';

import '../../components/bow_scaffold.dart';
import '../../components/glass.dart';
import '../../themes/bow_theme.dart';
import '../../utils/l10n.dart';

/// Bản build thiếu cấu hình Firebase — nói rõ phải làm gì thay vì màn hình trắng.
class SetupNeededPage extends StatelessWidget {
  const SetupNeededPage({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return BowScaffold(
      children: [
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Chưa có cấu hình Firebase', 'Firebase is not configured'),
                style: TextStyle(
                  color: c.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t(
                  'Bản build này thiếu google-services.json / GoogleService-Info.plist. Chạy `flutterfire configure` ở gốc repo rồi build lại — xem README.md.',
                  'This build lacks google-services.json / GoogleService-Info.plist. Run `flutterfire configure` at the repo root and rebuild — see README.md.',
                ),
                style: TextStyle(color: c.ink, height: 1.45),
              ),
              const SizedBox(height: 12),
              SelectableText(
                error,
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
