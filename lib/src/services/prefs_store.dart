import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Các lựa chọn LẺ của người dùng — một khoá một con số — trong vùng dữ liệu riêng của app. Lựa chọn có nhiều phần đi
/// cùng nhau (giao diện) có kho riêng.
class PrefsStore {
  const PrefsStore();

  Future<int?> readInt(String key) async =>
      (await SharedPreferences.getInstance()).getInt(key);

  Future<void> writeInt(String key, int value) async =>
      (await SharedPreferences.getInstance()).setInt(key, value);
}

final prefsStoreProvider = Provider<PrefsStore>((ref) => const PrefsStore());
