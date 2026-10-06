import 'dart:ui';

/// Ngôn ngữ người dùng ÉP ở Cài đặt → Giao diện (`'vi'` / `'en'`); `null` = theo ngôn ngữ của máy. Là biến toàn cục
/// vì [t] được gọi ở mọi nơi, kể cả ViewModel và phần chạy nền — những chỗ không có `BuildContext`. Chỉ `AppearanceVm`
/// được ghi.
String? forcedLanguage;

/// Giao diện hai thứ tiếng: tiếng Việt khi người dùng chọn tiếng Việt (hoặc máy đặt tiếng Việt), còn lại tiếng Anh.
String t(String vi, String en) =>
    (forcedLanguage ?? PlatformDispatcher.instance.locale.languageCode) == 'vi'
    ? vi
    : en;
