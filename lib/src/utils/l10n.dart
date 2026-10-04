import 'dart:ui';

/// Giao diện theo ngôn ngữ máy: tiếng Việt khi máy đặt tiếng Việt, còn lại tiếng Anh.
String t(String vi, String en) =>
    PlatformDispatcher.instance.locale.languageCode == 'vi' ? vi : en;
