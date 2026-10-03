import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'pairing.dart';

/// Quét mã QR ghép máy. Trả chuỗi mã ghép qua `Navigator.pop` ngay khi thấy một mã của bow; QR khác bị bỏ qua.
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

  void _onDetect(BarcodeCapture capture) {
    if (_found) return;
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Text(widget.hint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
