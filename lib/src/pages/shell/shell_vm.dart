import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bốn mục của thanh điều hướng dưới — thứ tự ở đây là thứ tự trên thanh.
enum ShellTab { today, tabs, activity, settings }

/// Mục đang mở. Là provider (không phải state riêng của khung) để màn con cũng chuyển mục được — "Xem tất cả" ở
/// Hôm nay mở Hoạt động, dòng cảnh báo mở Cài đặt.
class ShellVm extends Notifier<ShellTab> {
  @override
  ShellTab build() => ShellTab.today;

  void open(ShellTab tab) => state = tab;
}

final shellVmProvider = NotifierProvider<ShellVm, ShellTab>(ShellVm.new);
