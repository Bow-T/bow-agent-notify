import 'package:flutter/material.dart';

import '../themes/bow_theme.dart';

import 'icon3d.dart';

/// Logo của app trong đĩa kính, có vòng sóng toả ra khi đang nghe — "agent còn sống và đang nối với máy này".
class ListeningMark extends StatefulWidget {
  const ListeningMark({super.key, required this.active});

  final bool active;

  @override
  State<ListeningMark> createState() => _ListeningMarkState();
}

class _ListeningMarkState extends State<ListeningMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat();
  }

  @override
  void didUpdateWidget(ListeningMark old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    if (widget.active) {
      _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final color = widget.active ? c.accent : c.muted;
    Widget ring(double phase) => AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = (_pulse.value + phase) % 1;
        return Container(
          width: 56 + 40 * t,
          height: 56 + 40 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: widget.active ? 0.5 * (1 - t) : 0),
              width: 1.5,
            ),
          ),
        );
      },
    );
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(0),
          ring(0.5),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: c.button,
              ),
              border: Border.all(color: c.rim),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 22,
                  spreadRadius: -6,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Opacity(
              opacity: widget.active ? 1 : 0.55,
              child: const Icon3d('logo_mark', size: 46),
            ),
          ),
        ],
      ),
    );
  }
}
