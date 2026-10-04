import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pairing.dart';

const _pairingsKey = 'pairings';

/// Danh sách máy đã ghép — lưu trong vùng dữ liệu riêng của app. Dùng chung cho màn chính và cho phần chạy NỀN
/// (thông báo tới lúc app đã tắt, nút bấm trên thông báo).
class PairingStore {
  const PairingStore();

  /// `fresh`: đọc lại từ đĩa — phần chạy nền là một isolate riêng, bộ nhớ đệm của nó không biết màn chính vừa ghép / bỏ ghép.
  Future<List<Pairing>> load({bool fresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (fresh) await prefs.reload();
    return (prefs.getStringList(_pairingsKey) ?? [])
        .map(Pairing.parse)
        .nonNulls
        .toList();
  }

  Future<void> save(List<Pairing> pairings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _pairingsKey,
      pairings.map((p) => p.uri).toList(),
    );
  }
}

final pairingStoreProvider = Provider<PairingStore>(
  (ref) => const PairingStore(),
);
