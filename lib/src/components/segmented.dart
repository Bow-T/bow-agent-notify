import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

/// Bộ chọn MỘT trong vài giá trị, các ô chia đều bề ngang (Cài đặt → Giao diện). Ô đang chọn nổi lên khỏi rãnh; ở
/// brutal nó là khối màu nhấn viền mực.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  /// Giá trị + nhãn của từng ô, theo thứ tự hiện.
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Container(
      padding: EdgeInsets.all(c.isBrutal ? 0 : 2),
      decoration: BoxDecoration(
        color: c.well,
        borderRadius: c.radius(11),
        border: Border.all(color: c.hairline, width: c.line),
      ),
      child: Row(
        children: [
          for (final (option, label) in options)
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => onChanged(option),
                  borderRadius: c.radius(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: option != value
                        ? null
                        : c.isBrutal
                        ? BoxDecoration(color: c.accent)
                        : BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: c.button,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 6,
                                spreadRadius: -2,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: option != value
                            ? c.muted
                            : c.isBrutal
                            ? c.onAccent
                            : c.ink,
                        fontSize: 13,
                        fontWeight: option == value
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
