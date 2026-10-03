import 'package:shared_preferences/shared_preferences.dart';

import 'pairing.dart';

/// Danh sách máy đã ghép — lưu trong vùng dữ liệu riêng của app. Dùng chung cho màn chính và cho phần chạy NỀN
/// (thông báo tới lúc app đã tắt, nút bấm trên thông báo).
const _pairingsKey = 'pairings';

/// `fresh`: đọc lại từ đĩa — phần chạy nền là một isolate riêng, bộ nhớ đệm của nó không biết màn chính vừa ghép / bỏ ghép.
Future<List<Pairing>> loadPairings({bool fresh = false}) async {
  final prefs = await SharedPreferences.getInstance();
  if (fresh) await prefs.reload();
  return (prefs.getStringList(_pairingsKey) ?? [])
      .map(Pairing.parse)
      .nonNulls
      .toList();
}

Future<void> savePairings(List<Pairing> pairings) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_pairingsKey, pairings.map((p) => p.uri).toList());
}
