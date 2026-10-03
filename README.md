# Bow Notify — app đồng hành nhận thông báo của bow-agent

App Flutter nhỏ, **chỉ nhận** thông báo đẩy (FCM) mà bow gửi khi agent chờ bạn duyệt, đang hỏi, hoặc một lượt chạy
dài vừa xong / lỗi. App không gọi về máy chạy bow và không duyệt từ xa — thấy thông báo thì về máy mà bấm.

Phía gửi nằm trong repo [bow-agent](https://github.com/Bow-T/bow-agent): `src/core/fcm.ts` + `src/web/pushWatch.ts`
(Cài đặt → **Thông báo điện thoại** trên web bow).

## Repo này đã gắn với dự án Firebase `bow-agent-ai`

| | |
| --- | --- |
| Dự án Firebase | `bow-agent-ai` |
| Android | `dev.bow.bow_notify` — `android/app/google-services.json` |
| iOS | `dev.bow.bowNotify` — `ios/Runner/GoogleService-Info.plist` |

Hai file cấu hình trên và `firebase.json` được commit (repo riêng tư, clone về là build được). Chúng chỉ định danh
app, không phải bí mật. **Khoá service account thì là bí mật** — nó chỉ nằm ở máy chạy bow
(`~/.bow-agent/push.json`), đừng bao giờ bỏ vào repo này.

FCM chỉ gửi được tới app thuộc **cùng dự án Firebase** với khoá service account của bên gửi; vì thế app nằm ở repo
riêng chứ không trong bow-agent (cấu hình và mã định danh là của từng người / từng công ty).

## Còn lại để dùng được

Cần Flutter 3.41.4 (`fvm use` đọc `.fvmrc`).

1. **Cài lên điện thoại**
   - Android: tải APK mới nhất —
     <https://github.com/Bow-T/bow-agent-notify/releases/latest/download/bow-notify.apk> — rồi mở file để cài (cho phép
     "cài từ nguồn không xác định" khi được hỏi). Repo riêng tư nên trình duyệt trên điện thoại phải đăng nhập tài khoản
     GitHub có quyền vào repo; chưa đăng nhập thì link báo 404. Web bow có sẵn nút **Tải APK** / **Chép link tải** trong
     hộp Thông báo điện thoại.
   - iOS: xem mục dưới, rồi `flutter run --release` với máy đã cắm.
2. **Nạp khoá cho bow**: [Firebase Console → Service accounts](https://console.firebase.google.com/project/bow-agent-ai/settings/serviceaccounts/adminsdk)
   → *Generate new private key* → trên web bow mở **Cài đặt → Thông báo điện thoại → Thiết lập**, dán nguyên nội dung
   file JSON vừa tải.
3. **Ghép máy**: trong app bấm **Quét mã ghép**, đưa camera vào mã QR ở hộp vừa mở. Không quét được thì bấm "Chép
   mã" trên web rồi bấm nút dán ở góc trên app.
4. Bấm **Gửi thử** trên web — điện thoại rung là xong. Lần đầu sau khi ghép có thể chậm tới một phút (FCM cần thời
   gian ghi nhận đăng ký topic).

### Riêng iOS

- Apple Developer → Keys → tạo khoá **APNs** (`.p8`) →
  [Firebase Console → Cloud Messaging](https://console.firebase.google.com/project/bow-agent-ai/settings/cloudmessaging)
  → *APNs Authentication Key* → tải lên. Thiếu bước này iOS không bao giờ nhận được gì.
- Mở `ios/Runner.xcworkspace` bằng Xcode → Signing & Capabilities → chọn **Team**. Quyền Push Notifications đã khai
  sẵn (`ios/Runner/Runner.entitlements`); Xcode tự đăng ký cho App ID khi ký tự động.
- Bundle id `dev.bow.bowNotify` đã có Team khác đăng ký thì phải đổi: sửa trong Xcode rồi chạy lại
  `flutterfire configure --project=bow-agent-ai --platforms=android,ios` để đăng ký app iOS mới.

## Nó hoạt động thế nào

- Mã QR chứa `bowpush://pair?t=<topic>&p=<dự án Firebase>&n=<tên máy>`. App kiểm dự án trong mã có khớp dự án nó
  được build cho không (lệch là không bao giờ nhận được gì, nên báo ngay), rồi `subscribeToTopic(<topic>)`.
- Topic là một chuỗi ngẫu nhiên 128 bit, đóng vai mật khẩu: **ai có mã QR là nhận được thông báo**. Lộ mã thì bấm
  "Đổi mã ghép" trên web — mọi điện thoại phải quét lại.
- Một điện thoại ghép được nhiều máy chạy bow (cùng dự án Firebase); mỗi máy một dòng, bỏ ghép từng máy.
- App đang mở: thông báo hiện trong danh sách "Vừa nhận" (Android không tự hiện thông báo khi app ở trước mặt).
  App chạy nền / đã tắt: hệ điều hành hiện như mọi thông báo khác.
- Thông báo cùng một lượt chạy **thay** nhau (không chồng thành dãy).

## Không nhận được thông báo?

| Triệu chứng | Chỗ xem |
| --- | --- |
| "Gửi thử" trên web báo lỗi | Dòng lỗi là nguyên văn của Google / FCM: khoá bị thu hồi, sai dự án, API *Firebase Cloud Messaging API (V1)* chưa bật. |
| Web báo đã gửi, điện thoại im | Vừa ghép xong thì chờ một phút rồi thử lại. Kiểm quyền thông báo của app; Android: kiểm chế độ tiết kiệm pin. |
| iOS không bao giờ nhận | Chưa tải khoá APNs lên Firebase, hoặc chưa chọn Team (không có quyền Push). Máy ảo iOS chỉ nhận push trên Mac chip Apple. |
| App báo "mã ghép thuộc dự án khác" | Khoá service account dán vào bow không thuộc dự án `bow-agent-ai`. |
| App mở lên báo "Chưa có cấu hình Firebase" | Thiếu `google-services.json` / `GoogleService-Info.plist` trong bản build. |

## Dùng cho một dự án Firebase khác

Đổi mã định danh app (Android: `applicationId` ở `android/app/build.gradle.kts`; iOS: bundle id trong Xcode), rồi:

```sh
dart pub global activate flutterfire_cli
flutterfire configure --project=<dự án của bạn> --platforms=android,ios
```

Lệnh này đăng ký app vào dự án đó và ghi đè ba file cấu hình ở trên.

## Phát hành APK mới

```sh
# tăng `version` trong pubspec.yaml trước
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk /tmp/bow-notify.apk     # tên file cố định ⇒ link "latest" không đổi
gh release create v<phiên bản> /tmp/bow-notify.apk --title "Bow Notify <phiên bản>" --notes "<có gì mới>"
```

Bản phát hành đang ký bằng khoá debug của máy build (`android/app/build.gradle.kts`). Cài lần đầu không sao; nhưng bản
build từ MÁY KHÁC có chữ ký khác nên không cài đè được — phải gỡ app cũ rồi cài lại (mất danh sách máy đã ghép, quét lại
mã là xong). Muốn cập nhật êm giữa nhiều máy build / CI thì tạo một keystore phát hành riêng.

## Phát triển

```sh
flutter analyze
flutter test        # khuôn mã ghép phải khớp pairingUri() ở src/core/fcm.ts của bow-agent
```
