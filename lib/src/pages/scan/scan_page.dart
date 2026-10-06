import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../components/glass.dart';
import '../../components/glass_button.dart';
import '../../components/icon3d.dart';
import '../../models/pairing.dart';
import '../../themes/bow_theme.dart';
import '../../utils/l10n.dart';
import 'paste_code_dialog.dart';

/// Quét mã QR ghép máy. Trả chuỗi mã ghép qua `Navigator.pop` ngay khi thấy một mã của bow; QR khác bị bỏ qua.
/// Không quét được (mở web bow trên chính điện thoại này, máy không có camera) thì dán mã bằng nút ở dưới.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  /// Camera báo cùng một mã nhiều khung liên tiếp — chỉ thoát trang một lần.
  bool _found = false;

  /// Hộp dán mã đang mở: camera thấy mã lúc này mà `pop` thì đóng nhầm cái hộp chứ không phải trang.
  bool _entering = false;

  /// Dán mã bằng tay thay cho quét.
  Future<void> _enterCode() async {
    _entering = true;
    final raw = await showPasteCodeDialog(context);
    _entering = false;
    if (raw == null || raw.trim().isEmpty || !mounted || _found) return;
    _found = true;
    Navigator.of(context).pop(raw);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_found || _entering) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && Pairing.parse(raw) != null) {
        _found = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hình camera gần như luôn tối ⇒ lớp phủ dùng bản TỐI của kính, bất kể máy đang ở chế độ sáng.
    return Theme(
      data: bowTheme(Bow.dark),
      child: Builder(
        builder: (context) {
          final c = Bow.of(context);
          return Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: Colors.white,
              title: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            body: Stack(
              children: [
                Positioned.fill(child: MobileScanner(onDetect: _onDetect)),
                // Khung ngắm.
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    minimum: const EdgeInsets.all(16),
                    child: Glass(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon3d('camera', size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.hint,
                                  style: TextStyle(color: c.ink, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GlassButton(
                            label: t('Dán mã ghép', 'Paste pairing code'),
                            onPressed: _enterCode,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
