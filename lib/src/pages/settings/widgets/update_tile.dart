import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/glass_button.dart';
import '../../../components/row_tile.dart';
import '../../../constants/links.dart';
import '../../../constants/version.dart';
import '../../../services/link_service.dart';
import '../../../services/update_service.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';

/// Cài đặt → Về ứng dụng: số phiên bản đang cài + nút kiểm tra bản mới. Chỉ hỏi GitHub khi người dùng bấm; có bản
/// mới thì nút thành "Tải về" (Android mở link APK; iPhone mở trang phát hành — không cài được APK).
class UpdateTile extends ConsumerStatefulWidget {
  const UpdateTile({super.key});

  @override
  ConsumerState<UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends ConsumerState<UpdateTile> {
  var _checking = false;

  /// Bản mới nhất đã hỏi được (`null` = chưa hỏi / hỏi hỏng).
  String? _latest;
  var _failed = false;

  bool get _newer => _latest != null && isNewerVersion(_latest!, appVersion);

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _failed = false;
    });
    String? latest;
    try {
      latest = await ref.read(updateServiceProvider).latestVersion();
    } catch (_) {
      latest = null;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _latest = latest;
      _failed = latest == null;
    });
  }

  Future<void> _download() async {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final opened = await ref
        .read(linkServiceProvider)
        .open(android ? latestApkUrl : releasesPageUrl);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            t(
              'Không mở được trình duyệt. Link tải: $latestApkUrl',
              'Could not open the browser. Download link: $latestApkUrl',
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final version = t('Phiên bản $appVersion', 'Version $appVersion');
    final status = _checking
        ? t('đang kiểm tra…', 'checking…')
        : _failed
        ? t('không kiểm tra được (cần mạng)', 'could not check (needs network)')
        : _newer
        ? t('đã có bản $_latest', 'version $_latest is available')
        : _latest != null
        ? t('đang là bản mới nhất', 'this is the latest')
        : null;
    return RowTile(
      icon: 'info',
      title: 'Bow Notify',
      subtitle: status == null ? version : '$version · $status',
      subtitleColor: _failed
          ? c.dangerInk
          : _newer
          ? c.accentInk
          : null,
      trailing: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _newer
            ? GlassButton(
                label: t('Tải về', 'Download'),
                kind: GlassButtonKind.primary,
                onPressed: _download,
              )
            : GlassButton(
                label: t('Kiểm tra', 'Check'),
                onPressed: _checking ? null : _check,
              ),
      ),
    );
  }
}
