/// Nơi phát hành app (GitHub Releases) — "Kiểm tra bản mới" hỏi ở đây, bản mới tải ở đây. Ai tự build app cho dự án
/// Firebase riêng và phát hành ở repo khác thì đổi hằng này.
const releasesRepo = 'Bow-T/bow-agent-notify';

/// Tên file APK trong mỗi bản phát hành — cố định, nên link "latest" không đổi theo phiên bản.
const apkAssetName = 'bow-notify.apk';

/// API trả bản phát hành mới nhất (`tag_name` dạng `v1.2.3`).
const latestReleaseApi =
    'https://api.github.com/repos/$releasesRepo/releases/latest';

/// File APK của bản mới nhất (mở bằng trình duyệt — lối dự phòng khi không cập nhật được ngay trong app).
const latestApkUrl =
    'https://github.com/$releasesRepo/releases/latest/download/$apkAssetName';

/// File APK của ĐÚNG một bản phát hành. Địa chỉ do app tự ghép từ tag, không lấy link trong câu trả lời của API: app
/// chỉ tải từ repo phát hành đã khai ở trên. Tag là MỘT đoạn của đường dẫn (dấu `/` trong tag bị mã hoá) — tag lạ
/// không trỏ được sang repo khác.
Uri apkUri(String tag) => Uri(
  scheme: 'https',
  host: 'github.com',
  pathSegments: [
    ...releasesRepo.split('/'),
    'releases',
    'download',
    tag,
    apkAssetName,
  ],
);

/// Trang các bản phát hành (iOS không cài được APK — xem ghi chú và tự build).
const releasesPageUrl = 'https://github.com/$releasesRepo/releases/latest';

/// Tài liệu đầy đủ.
const readmeUrl = 'https://github.com/$releasesRepo#readme';
