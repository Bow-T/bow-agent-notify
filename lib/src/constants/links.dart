/// Nơi phát hành app (GitHub Releases) — "Kiểm tra bản mới" hỏi ở đây, "Tải về" mở link tải ở đây. Ai tự build app
/// cho dự án Firebase riêng và phát hành ở repo khác thì đổi hằng này.
const releasesRepo = 'Bow-T/bow-agent-notify';

/// API trả bản phát hành mới nhất (`tag_name` dạng `v1.2.3`).
const latestReleaseApi =
    'https://api.github.com/repos/$releasesRepo/releases/latest';

/// File APK của bản mới nhất — tên file cố định nên link không đổi theo phiên bản.
const latestApkUrl =
    'https://github.com/$releasesRepo/releases/latest/download/bow-notify.apk';

/// Trang các bản phát hành (iOS không cài được APK — xem ghi chú và tự build).
const releasesPageUrl = 'https://github.com/$releasesRepo/releases/latest';

/// Tài liệu đầy đủ.
const readmeUrl = 'https://github.com/$releasesRepo#readme';
