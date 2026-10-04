/// Phiên bản app hiện ở đầu màn hình — để biết máy đang cài bản nào khi đối chiếu với bản trên Releases.
/// Phải khớp `version` trong pubspec.yaml (phần trước dấu +): `test/version_test.dart` đỏ khi lệch, nên đổi một bên là
/// phải đổi bên kia. Hằng số chứ không đọc từ hệ điều hành lúc chạy để khỏi thêm một gói chỉ cho một dòng chữ.
const appVersion = '1.6.0';
