import 'package:flutter/material.dart';

import '../../../components/glass.dart';
import '../../../components/icon3d.dart';
import '../../../models/pairing.dart';
import '../../../themes/bow_theme.dart';
import '../../../utils/l10n.dart';

/// Một máy đã ghép: tên máy, dự án Firebase, có duyệt được từ điện thoại này không, và nút bỏ ghép.
class MachineTile extends StatelessWidget {
  const MachineTile({super.key, required this.pairing, required this.onUnpair});

  final Pairing pairing;
  final VoidCallback onUnpair;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          const Icon3d('agent', size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pairing.host.isEmpty ? pairing.projectId : pairing.host,
                  style: TextStyle(
                    color: c.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  pairing.canApprove
                      ? t(
                          'Firebase · ${pairing.projectId} · duyệt được từ đây',
                          'Firebase · ${pairing.projectId} · can approve here',
                        )
                      : 'Firebase · ${pairing.projectId}',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onUnpair,
            tooltip: t('Bỏ ghép', 'Unpair'),
            icon: const Icon3d('trash', size: 26),
          ),
        ],
      ),
    );
  }
}
