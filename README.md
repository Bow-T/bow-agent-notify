# Bow Notify — app đồng hành nhận thông báo của bow-agent

App Flutter nhỏ, **chỉ nhận** thông báo đẩy (FCM) mà bow gửi khi agent chờ bạn duyệt, đang hỏi, hoặc một lượt chạy
dài vừa xong / lỗi. App không gọi về máy chạy bow và không duyệt từ xa — thấy thông báo thì về máy mà bấm.

Phía gửi nằm trong repo [bow-agent](https://github.com/Bow-T/bow-agent): `src/core/fcm.ts` + `src/web/pushWatch.ts`
(Cài đặt → **Thông báo điện thoại** trên web bow).

## Vì sao phải tự build

FCM chỉ gửi được tới app thuộc **cùng dự án Firebase** với khoá service account của bên gửi. Repo này không chứa cấu
hình Firebase của ai cả, nên mỗi người (hoặc mỗi công ty) tạo một dự án Firebase rồi build app của mình. Làm một lần;
cả công ty dùng chung một dự án Firebase thì build một bản rồi phát cho mọi người.

Vì thế app nằm ở repo riêng chứ không trong bow-agent: `flutterfire configure` sửa cả file đã track (Gradle,
`project.pbxproj`) và bạn phải đổi mã định danh app — những thay đổi đó thuộc về bản của bạn.

## Thiết lập (khoảng 15 phút)

Cần: Flutter 3.41.4 (`fvm use` đọc `.fvmrc`), [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup)
(`dart pub global activate flutterfire_cli`), Firebase CLI đã `firebase login`.

1. **Tạo dự án Firebase** ở [console.firebase.google.com](https://console.firebase.google.com) (gói miễn phí là đủ,
   không cần bật Analytics).
2. **Gắn app vào dự án**, chạy ở gốc repo này:
   ```sh
   flutterfire configure --platforms=android,ios
   ```
   Lệnh này đăng ký app Android + iOS, tải `google-services.json` / `GoogleService-Info.plist` và gắn plugin Google
   Services vào Gradle. Mã định danh mặc định là `dev.bow.bow_notify` (Android) / `dev.bow.bowNotify` (iOS) — bundle
   id của iOS là duy nhất toàn Apple nên hãy đổi sang của bạn TRƯỚC bước này (Xcode → Runner → Signing & Capabilities).
3. **iOS — cho phép gửi qua APNs** (Android bỏ qua bước này):
   - Apple Developer → Keys → tạo khoá **APNs** (`.p8`) → Firebase Console → Project settings → Cloud Messaging →
     *APNs Authentication Key* → tải lên.
   - Mở `ios/Runner.xcworkspace` bằng Xcode → Signing & Capabilities → chọn **Team**. Quyền Push Notifications đã
     khai sẵn (`ios/Runner/Runner.entitlements`); Xcode tự đăng ký cho App ID khi ký tự động.
4. **Cài lên điện thoại**: `flutter run --release` (cắm máy), hoặc `flutter build apk` rồi chép file APK sang.
5. **Nạp khoá cho bow**: Firebase Console → Project settings → Service accounts → *Generate new private key* → trên
   web bow mở **Cài đặt → Thông báo điện thoại → Thiết lập**, dán nguyên nội dung file JSON.
6. **Ghép máy**: trong app bấm **Quét mã ghép**, đưa camera vào mã QR ở hộp vừa mở. Không quét được (điện thoại và
   máy tính là một) thì bấm "Chép mã" trên web rồi bấm nút dán ở góc trên app.
7. Bấm **Gửi thử** trên web — điện thoại rung là xong. Lần đầu sau khi ghép có thể chậm tới một phút (FCM cần thời
   gian ghi nhận đăng ký topic).

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
| App báo "mã ghép thuộc dự án khác" | App build bằng `flutterfire configure` của dự án A, còn bow dùng khoá của dự án B. |
| App mở lên báo "Chưa có cấu hình Firebase" | Chưa chạy bước 2, hoặc chạy xong chưa build lại. |

## Phát triển

```sh
flutter analyze
flutter test        # khuôn mã ghép phải khớp pairingUri() ở src/core/fcm.ts của bow-agent
```

Các file `flutterfire configure` sinh ra (`google-services.json`, `GoogleService-Info.plist`, `lib/firebase_options.dart`,
`firebase.json`) nằm trong `.gitignore` để bản mẫu không mang cấu hình của ai. Repo của bạn là riêng tư và cần CI build
được thì bỏ các dòng đó khỏi `.gitignore` rồi commit chúng (chúng không phải bí mật; **khoá service account thì có** —
khoá đó chỉ nằm ở máy chạy bow, đừng bao giờ bỏ vào repo này).
