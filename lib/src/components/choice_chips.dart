import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

/// Hàng chip chọn MỘT (bộ lọc): chip đang chọn tô màu nhấn, còn lại là viên lõm (brutal: ô vuông viền mực).
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  /// Giá trị + nhãn của từng chip, theo thứ tự hiện.
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final (option, label) in options)
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => onChanged(option),
              customBorder: c.isBrutal ? null : const StadiumBorder(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: option == value
                      ? c.accent
                      : c.isBrutal
                      ? c.surface
                      : c.well,
                  borderRadius: c.radius(999),
                  border: Border.all(
                    color: option == value && !c.isBrutal
                        ? Colors.transparent
                        : c.hairline,
                    width: c.line,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: option == value ? c.onAccent : c.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
