# Bow Notify — app đồng hành nhận thông báo của bow-agent

App Flutter nhỏ nhận thông báo đẩy (FCM) mà bow gửi khi agent chờ bạn duyệt, đang hỏi, hoặc một lượt chạy dài vừa
xong / lỗi. Mặc định app chỉ báo; bật thêm *Duyệt từ điện thoại* thì duyệt được ngay trong app hoặc ngay trên thông báo
(xem dưới). App không bao giờ gọi về máy chạy bow.

Phía gửi nằm trong repo [bow-agent](https://github.com/Bow-T/bow-agent): `src/core/fcm.ts` + `src/web/pushWatch.ts`
(Cài đặt → **Thông báo điện thoại** trên web bow).

## Repo này đã gắn với dự án Firebase `bow-agent-ai`

| | |
| --- | --- |
| Dự án Firebase | `bow-agent-ai` |
| Android | `dev.bow.bow_notify` — `android/app/google-services.json` |
| iOS | `dev.bow.bowNotify` — `ios/Runner/GoogleService-Info.plist` |

Hai file cấu hình trên và `firebase.json` được commit (clone về là build được). Chúng chỉ định danh app, không phải
bí mật — APK nào cũng mang sẵn đúng các giá trị đó. **Khoá service account thì là bí mật** — nó chỉ nằm ở máy chạy bow
(`~/.bow-agent/push.json`), đừng bao giờ bỏ vào repo này. **Mã ghép máy (QR) cũng vậy**: nó là chìa khoá duyệt, đừng
dán vào issue, ảnh chụp màn hình hay test.

Repo này **công khai** (từ 2026-10-04) để điện thoại tải APK thẳng từ Releases mà không cần đăng nhập GitHub.

FCM chỉ gửi được tới app thuộc **cùng dự án Firebase** với khoá service account của bên gửi; vì thế app nằm ở repo
riêng chứ không trong bow-agent (cấu hình và mã định danh là của từng người / từng công ty).

## Còn lại để dùng được

Cần Flutter 3.41.4 (`fvm use` đọc `.fvmrc`).

1. **Cài lên điện thoại**
   - Android: tải APK mới nhất —
     <https://github.com/Bow-T/bow-agent-notify/releases/latest/download/bow-notify.apk> — rồi mở file để cài (cho phép
     "cài từ nguồn không xác định" khi được hỏi). Repo công khai nên link tải được ngay, không cần đăng nhập GitHub.
     Web bow có sẵn nút **Tải APK** / **Chép link tải** trong hộp Thông báo điện thoại.
   - iOS: xem mục dưới, rồi `flutter run --release` với máy đã cắm.
2. **Nạp khoá cho bow**: [Firebase Console → Service accounts](https://console.firebase.google.com/project/bow-agent-ai/settings/serviceaccounts/adminsdk)
   → *Generate new private key* → trên web bow mở **Cài đặt → Thông báo điện thoại → Thiết lập**, dán nguyên nội dung
   file JSON vừa tải.
3. **Ghép máy**: trong app bấm nút quét ở góc trên (lần đầu còn có nút **Quét mã ghép** to ở giữa màn; về sau ghép thêm
   máy ở *Cài đặt → Ghép máy khác*), đưa camera vào mã QR ở hộp vừa mở. Không quét được thì bấm "Chép mã" trên web rồi
   bấm **Dán mã ghép** (ở thẻ lần đầu hoặc trong màn quét).
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

## Bốn mục của app

Thanh điều hướng dưới có bốn mục; thanh trên chỉ có logo và nút quét mã ghép.

| Mục | Có gì |
| --- | --- |
| **Hôm nay** | Thứ đang cần bạn: thẻ chờ duyệt, câu agent hỏi, lời mời trả lời, và vài thông báo vừa tới. Số thẻ đang chờ hiện trên thanh dưới ở mọi mục. Chưa ghép máy nào thì đây là màn hướng dẫn ghép. |
| **Tab** | Thanh tab của trang bow trên máy (lọc: tất cả / đang chạy / chờ bạn), chạm để đọc hội thoại và gõ tiếp, nút *Giao việc mới*. |
| **Hoạt động** | Mọi thông báo đã tới từ lúc mở app. |
| **Cài đặt** | Máy đã ghép (ghép thêm / bỏ ghép), quyền thông báo, widget màn hình chính, phiên bản. |

## Nó hoạt động thế nào

- Mã QR chứa `bowpush://pair?t=<topic>&p=<dự án Firebase>&n=<tên máy>`. App kiểm dự án trong mã có khớp dự án nó
  được build cho không (lệch là không bao giờ nhận được gì, nên báo ngay), rồi `subscribeToTopic(<topic>)`.
- Topic là một chuỗi ngẫu nhiên 128 bit, đóng vai mật khẩu: **ai có mã QR là nhận được thông báo**. Lộ mã thì bấm
  "Đổi mã ghép" trên web — mọi điện thoại phải quét lại.
- Một điện thoại ghép được nhiều máy chạy bow (cùng dự án Firebase); mỗi máy một dòng ở Cài đặt, bỏ ghép từng máy.
- App đang mở: thông báo hiện ở "Vừa nhận" của mục Hôm nay và trong mục Hoạt động (Android không tự hiện thông báo khi
  app ở trước mặt).
  App chạy nền / đã tắt: hệ điều hành hiện như mọi thông báo khác.
- Thông báo cùng một lượt chạy **thay** nhau (không chồng thành dãy).

## Duyệt ngay trên điện thoại (tuỳ chọn)

Mặc định app chỉ báo. Bật ở web bow: hộp Thông báo điện thoại → **Duyệt từ điện thoại → Qua Firebase**, dán địa chỉ
Realtime Database của dự án, rồi **quét lại mã QR** (mã mới mang thêm khoá duyệt). Dòng máy đã ghép sẽ ghi "duyệt được
từ đây", và khi agent chờ bạn, nhóm **Chờ bạn duyệt** hiện ở mục Hôm nay:

- Thẻ duyệt: xem lệnh rồi bấm **Cho phép** / **Từ chối**. Thao tác rủi ro (`git push`, `rm`…) có nhãn "Rủi ro" và đòi
  vân tay / Face ID / mật mã máy trước khi gửi. Máy chưa đặt khoá màn hình thì hỏi lại bằng một hộp xác nhận.
- Thẻ câu hỏi: chọn đáp án rồi **Gửi**, hoặc **Bỏ qua**.
- Thẻ sửa file chỉ hiện đường dẫn + số dòng thay đổi — muốn soi nội dung thì về máy.
- Thẻ **trả lời** (dấu tích xanh): lượt đã xong và bow mời vài câu gõ tiếp — "push", "tiếp", "commit/push", hoặc câu agent
  mời. Bấm một câu là tab trên máy gửi đúng câu đó, lượt mới chạy tiếp. Chỉ chọn được câu đang mời, không gõ tự do; không
  chọn gì thì lượt cứ nằm đó như khi bạn rời bàn. Trang bow trên máy phải còn mở. Lời agent là Markdown và được DỰNG
  (đậm, danh sách, code, bảng) — trong thẻ, trên thông báo và trên widget; thẻ mở ra ở cuối đoạn, nơi agent mời trả lời.
  Lệnh ở thẻ duyệt thì ngược lại: giữ nguyên từng ký tự, không dựng gì.

### Duyệt ngay trên thông báo (Android)

Không cần mở app: thông báo hiện luôn lệnh cần duyệt kèm nút (`lib/src/services/notification_service.dart`).

- Thẻ duyệt thường: **Cho phép** / **Từ chối**. Thẻ rủi ro: **Mở để duyệt** / **Từ chối** — không có nút Cho phép,
  vì cho phép thao tác rủi ro phải qua vân tay, mà vân tay cần mở app.
- Câu hỏi gọn (một câu, chọn một, tối đa ba lựa chọn — Android chỉ hiện ba nút): mỗi lựa chọn một nút. Câu hỏi khác:
  **Mở để trả lời**.
- Thông báo "đã xong" có lời mời trả lời: mỗi câu một nút (ba câu đầu), kèm đoạn cuối lời agent để biết đang trả lời gì.
- Màn hình khoá không hiện lệnh, không hiện nút — mở khoá rồi mới thấy.
- Cách làm: thông báo đẩy mang mã thẻ (chỉ mã, không nội dung). App tra đúng thẻ đó trên Realtime Database, giải mã
  bằng khoá ghép máy, rồi thay thông báo hệ điều hành vừa hiện bằng bản có nút. Bấm nút thì app đọc lại thẻ (không tin
  thứ nằm trong thông báo) rồi mới gửi quyết định — kể cả khi app đã tắt.
- Thẻ đã được xử lý ở nơi khác (trong app, trên web): thông báo của nó tự gỡ khi app đang mở; app đang tắt thì thông báo
  nằm lại, bấm nút sẽ nhận câu "thẻ không còn chờ".
- Máy không cho app chạy nền (tiết kiệm pin gắt) thì vẫn có thông báo thường như trước, bấm vào là mở app.
- Cần bow-agent bản có gửi mã thẻ; bản cũ hơn thì thông báo như trước, không có nút. iOS chưa có nút trên thông báo.

### Tab trên máy — xem trang bow từ xa, gõ vào tab, giao việc mới

Bật ở web bow: hộp Thông báo điện thoại → tick **Xem tab và hội thoại trên điện thoại** (cần đang bật *Qua Firebase*).
Mục **Tab** của app hiện thanh tab của trang bow — tab nào đang chạy, tab nào đang chờ bạn. Chạm vào một
tab để đọc ~40 dòng cuối của hội thoại (đề bài, dòng tool, lời agent dựng Markdown), cập nhật trong lúc lượt chạy.

- **Mặc định chỉ xem.** Duyệt / trả lời nhanh vẫn ở thẻ "Chờ bạn duyệt".
- **Gõ vào tab** (từ 1.8): khi máy bật thêm *Cho gõ và giao việc từ điện thoại*, màn hội thoại có ô nhập. Câu bạn gõ được
  tab trên máy tự gửi cho agent — y như gõ ở máy (tab đang chạy thì thành lời nói chen); lượt đó vẫn qua cổng duyệt.
  - Lần đầu phải qua vân tay / khuôn mặt / mật mã máy; sau đó mở khoá gõ **5 phút**, app ra nền là khoá lại.
  - Mỗi câu là một lệnh đã mã hoá bằng khoá ghép máy, dùng một lần; app chờ máy báo lại rồi mới coi là đã gửi.
  - Không tới thì app nói rõ vì sao (trang bow không mở, tab đã đóng, khung soạn trên máy đang có tệp đính kèm, đồng hồ
    lệch…) và giữ nguyên câu trong ô nhập để gửi lại.
- **Giao việc mới** (từ 1.9, cùng công tắc trên): nút **Giao việc mới** dưới danh sách tab → chọn dự án, gõ đề bài, gửi.
  Trang bow mở một tab MỚI ở dự án đó (không chuyển tab đang mở trên máy) rồi tự gửi đề bài; app sang thẳng hội thoại
  của tab vừa mở.
  - Chỉ chọn được **dự án đã đăng ký trên máy** (danh sách đi cùng thanh tab) — không gõ đường dẫn. Chọn sẵn dự án của
    tab đang mở trên máy. Máy chỉ có một thư mục (mode chia sẻ) thì không có ô chọn.
  - Tab mới dùng model và mode của tab gần nhất cùng dự án. Hai công tắc **Tự duyệt** và **Autopilot A–Z** nằm ngay trên
    màn này, **mặc định tắt và không thừa kế** — mỗi việc tự chọn agent được tự làm tới đâu.
  - **Luôn hỏi vân tay** (không dùng phiên mở khoá 5 phút của ô gõ). Gửi xong thì phiên gõ được mở luôn để câu tiếp
    theo trong tab mới khỏi hỏi lại.
  - Thao tác cần duyệt của lượt đó vẫn báo về điện thoại như mọi lượt khác.
- Dữ liệu là của trang web: web báo cái nó đang hiện, server mã hoá bằng khoá ghép máy rồi chép lên Realtime Database,
  app đọc theo luồng (đổi là thấy sau chừng một giây). Kết quả tool và nội dung sửa file không đi.
- Trang bow phải đang mở. Trang đóng / máy ngủ quá ~2,5 phút thì app ghi rõ "không báo về từ HH:mm" — thứ đang hiện
  là bản cuối cùng nhận được.
- App khuất thì đóng mọi luồng (không giữ kết nối khi không ai nhìn); mở lại là nghe tiếp.

Mã: `lib/src/services/mirror_service.dart` (đọc + nghe luồng + gửi lệnh), `lib/src/pages/tabs/` (`tabs_vm.dart` thanh
tab, `tab_vm.dart` + `tab_page.dart` hội thoại của một tab, `new_task_vm.dart` + `new_task_page.dart` giao việc mới,
`typing_gate.dart` chốt mở khoá gõ),
`lib/src/models/rtdb_event.dart` (sự kiện của luồng database).

### Widget màn hình chính (Android)

Hai widget, thêm từ bảng chọn widget của máy hoặc bấm **Thêm thẻ chờ duyệt** / **Thêm viên trạng thái** ngay trong app:

- **Chờ bạn duyệt** (4×2, kéo giãn được): thẻ đang chờ — tên tác vụ, lệnh, và nút y như trên thông báo (Cho phép / Từ
  chối, các câu trả lời, các lựa chọn của câu hỏi ngắn). Thao tác rủi ro chỉ có **Mở để duyệt** — cho phép nó phải qua vân
  tay trong app. Không có gì chờ thì hiện lượt vừa xong / lỗi gần nhất. Kéo widget cao lên là thấy thêm dòng của lệnh.
- **Trạng thái** (viên thuốc 2×1): đang có mấy việc chờ. Chạm là mở app.

Thẻ đang CHẶN agent (xin duyệt, câu hỏi) được đưa lên trước lời mời trả lời. Widget theo chế độ sáng / tối của máy.

Widget không tự hỏi mạng theo nhịp (hệ điều hành không cho) — nó được làm mới khi: có thông báo đẩy tới, bạn vừa quyết
định (ở đâu cũng vậy), app đang mở, bạn bấm ↻, và mỗi 30 phút. Vì thế một thẻ đã được bấm ở web mà không có thông báo
nào theo sau có thể nằm lại trên widget tới lần làm mới kế; bấm nút của nó thì không gửi gì, widget tự vẽ lại.

Phần vẽ ở Kotlin (`android/…/BowWidgets.kt`, chỉ đọc dữ liệu rồi gán vào view); chữ nào hiện, nút nào có đều quyết ở
Dart (`lib/src/models/widget_snapshot.dart` → `lib/src/services/home_widget_service.dart`). Cú chạm vào nút chạy về
Dart ở isolate nền, đọc lại thẻ thật từ bản mã của server rồi mới gửi — cùng luật với nút trên thông báo. Receiver nhận
cú chạm KHÔNG exported: app khác không gửi được "cho phép" giả vào. iOS chưa có widget.

Nó hoạt động thế nào (`lib/src/services/remote_service.dart`, nửa server ở `src/core/remoteApproval.ts` của bow-agent):

- Máy chạy bow ghi thẻ lên Realtime Database, app đọc (mỗi 4 giây khi app đang mở, và ngay khi có thông báo tới);
  app ghi quyết định, máy chạy bow đọc rồi tự áp. Khác mạng vẫn được, máy chạy bow không mở cổng nào.
- Mọi thứ đi qua đó là bản mã AES-256-GCM bằng **khoá ghép máy** trong mã QR: Google chỉ thấy bản mã, và quyết định
  không tạo được bằng đúng khoá thì máy chạy bow bỏ. Vì thế **mã QR lúc này là chìa khoá duyệt** — lộ thì bấm "Đổi mã
  ghép" trên web.
- Khoá lưu trong vùng dữ liệu riêng của app (SharedPreferences), không hiện ra màn hình, không ghi log, và KHÔNG được
  sao lưu / chuyển sang máy khác (Android: `allowBackup="false"` + `data_extraction_rules.xml`) — đổi máy thì quét lại mã.
- Vân tay là chốt ở phía app: nó chặn chạm nhầm và người khác cầm máy đang mở khoá, không chặn được kẻ đã có khoá ghép.

## Giao diện và âm báo

- Giao diện theo theme **kính** của web bow: hình nền Cực quang, tấm kính mờ, nút viên thuốc, dấu hồng tâm. Bảng màu
  chép từ `web/styles.css` của bow-agent vào `lib/src/themes/bow_theme.dart` (hai bản sáng / tối theo máy) — đổi màu ở web thì đổi
  lại ở đó.
- **Mỗi việc một âm riêng**, nghe là biết mà không cần nhìn máy:

  | Âm | Khi nào | Kênh Android |
  | --- | --- | --- |
  | `bow_ask` — đi lên, bỏ lửng | agent chờ bạn duyệt / đang hỏi / gửi thử | `bow_ask` |
  | `bow_done` — hợp âm trưởng rải lên rồi đậu lại | lượt chạy xong | `bow_done` |
  | `bow_fail` — đi xuống, trầm | lượt chạy lỗi | `bow_fail` |

  Ba âm được **tổng hợp** bằng `python3 tool/make_sounds.py` (không dùng mẫu thu sẵn), ghi ra
  `android/app/src/main/res/raw/` và `ios/Runner/`. Muốn đổi âm thì sửa bảng nốt trong script rồi chạy lại.
  Android khoá âm theo kênh ngay lúc tạo: đổi âm của kênh đã có thì phải đổi cả ID kênh (`MainActivity.kt`) lẫn
  `channel_id` server gửi (`src/core/fcm.ts` của bow-agent).
- Android không tự hiện thông báo khi app đang mở, nên app tự dựng (kênh native `bow/notify`) — vẫn kêu, vẫn hiện nổi.
- Sau khi cập nhật app phải **mở app một lần** để các kênh thông báo mới được tạo.
- **Icon là bộ "kẹo 3D" của web bow** (`web/icons3d.ts` bên bow-agent): khiên = chờ duyệt, bong bóng = đang hỏi, bi
  xanh = xong, bi đỏ = lỗi… **Logo app** = "quả cầu agent": quả cầu chàm có mắt agent, chuông thông báo tựa ở góc
  (chuông lấy từ bộ icon, quả cầu vẽ trong `tool/export_icons.mts` bằng cùng cách dựng).
  Hai repo không chung mã nên hình được xuất sang đây:
  ```sh
  node --import <bow-agent>/node_modules/tsx/dist/esm/index.mjs tool/export_icons.mts <bow-agent>/web/icons3d.ts   # → tool/icons/*.svg
  tool/render_icons.sh   # → assets/icons/*.png, icon app iOS, lớp trước icon thích ứng Android (cần `brew install librsvg`)
  ```
  Nút trên nền lam (Quét mã ghép) dùng icon phẳng màu trắng — hình 3D có màu riêng nên chìm trên nền màu nhấn.
  Icon thông báo trên thanh trạng thái và icon "theo màu chủ đề" của Android là hình quả cầu MỘT MÀU (vector trong
  `res/drawable`) vì Android chỉ lấy hình rồi tự tô màu.

## Không nhận được thông báo?

| Triệu chứng | Chỗ xem |
| --- | --- |
| "Gửi thử" trên web báo lỗi | Dòng lỗi là nguyên văn của Google / FCM: khoá bị thu hồi, sai dự án, API *Firebase Cloud Messaging API (V1)* chưa bật. |
| Máy ghi "đã ghép", mở app vẫn thấy thẻ, nhưng KHÔNG thông báo nào tới | Đăng ký nhận thông báo đã mất (cài lại app, khôi phục dữ liệu, mã nhận của máy đổi). Từ bản 1.6.1 app tự đăng ký lại mỗi lần mở — mở app một lần khi có mạng; máy nào chưa đăng ký được sẽ có dòng đỏ dưới tên. Bản cũ hơn: bỏ ghép rồi quét lại mã. |
| Web báo đã gửi, điện thoại im | Vừa ghép xong thì chờ một phút rồi thử lại. Kiểm quyền thông báo của app; Android: kiểm chế độ tiết kiệm pin. |
| Có thông báo nhưng không kêu | Máy đang im lặng / rung; hoặc kênh `Bow · …` bị tắt âm trong Cài đặt → Thông báo của app. Một số máy (Xiaomi, Oppo…) tắt sẵn âm + hiện nổi của app cài ngoài — bật lại ở đó. |
| iOS không bao giờ nhận | Chưa tải khoá APNs lên Firebase, hoặc chưa chọn Team (không có quyền Push). Máy ảo iOS chỉ nhận push trên Mac chip Apple. |
| App báo "mã ghép thuộc dự án khác" | Khoá service account dán vào bow không thuộc dự án `bow-agent-ai`. |
| Thẻ không hiện ở "Chờ bạn duyệt" | Máy đó chưa bật *Duyệt từ điện thoại* (dòng máy đã ghép không ghi "duyệt được từ đây") → bật trên web rồi quét lại mã. Thẻ chỉ lên sau khi treo 1,5 giây. |
| Thông báo không có nút duyệt | Cần app từ 1.4 + bow-agent bản gửi mã thẻ + máy đã ghép ghi "duyệt được từ đây". Máy chặn app chạy nền (tiết kiệm pin) thì chỉ có thông báo thường — cho app vào danh sách không tối ưu pin. |
| Thông báo "đã xong" không có nút trả lời | Cần app từ 1.5 + bow-agent bản có lời mời trả lời. Lượt ngắn hơn 60 giây không báo (trừ khi bạn vừa thao tác từ điện thoại); ô nhập trên máy đang có bản nháp thì không mời; trang bow đã đóng thì không ai gửi được câu trả lời. |
| Mục Tab ghi "Chưa có tab nào" | Máy đó chưa tick *Xem tab và hội thoại trên điện thoại* (hoặc chưa bật *Qua Firebase*), điện thoại ghép từ trước khi có khoá duyệt, hay trang bow chưa mở lần nào từ lúc bật. Cần app từ 1.7. |
| Màn hội thoại không có ô nhập / không có nút Giao việc mới | Máy đó chưa tick *Cho gõ và giao việc từ điện thoại* (nút giao việc cần thêm bow-agent bản có giao việc mới + app từ 1.9), tab đã đóng, hoặc trang bow đã im quá vài phút (ô nhập ẩn vì gửi cũng không ai nhận). Sau khi bật trên web, chờ tối đa nửa phút. |
| Widget không cập nhật | Widget chỉ làm mới khi có thông báo tới, sau một quyết định, khi app mở, khi bấm ↻, hoặc mỗi 30 phút. Máy chặn app chạy nền (tiết kiệm pin) thì thông báo không gọi dậy được app — cho app vào danh sách không tối ưu pin. |
| Bấm Cho phép báo "Không gửi được" | Thẻ đã có trả lời (mỗi thẻ ghi một lần), hoặc bow không còn chạy / trang bow đã đóng. |
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
# tăng `version` trong pubspec.yaml VÀ `appVersion` ở lib/src/constants/version.dart (số hiện ở Cài đặt → Về ứng dụng; test bắt khi lệch)
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

### Cấu trúc mã — MVVM + Riverpod

Cùng cách chia thư mục với app Flutter của monorepo (`pages/<màn>/…_page.dart` + `…_vm.dart`, `components`, `models`,
`services`, `themes`), chỉ khác: ViewModel là `Notifier` của Riverpod và service lấy qua provider.

```
lib/
  main.dart                     khởi động: Firebase, thông báo, ProviderContainer
  app/app.dart                  MaterialApp + theme
  src/
    models/                     dữ liệu + luật thuần (không Flutter, không mạng)
      pairing.dart                mã ghép máy
      pending_card.dart           thẻ chờ duyệt / câu hỏi / lời mời trả lời
      card_action.dart            nút của một thẻ + quyết định ứng với từng nút
      card_ref.dart               thứ gắn theo thông báo, sổ thông báo có nút đang hiện
      widget_snapshot.dart        mọi thứ widget màn hình chính cần để vẽ
      received.dart               thông báo vừa nhận
      mirror.dart                 tab trên máy: thanh tab, dự án, dòng chat
      rtdb_event.dart             sự kiện của luồng Realtime Database
    services/                   nói chuyện với bên ngoài — mỗi service một provider
      push_service.dart           FCM: quyền, tin tới, đăng ký topic
      remote_service.dart         Realtime Database + mã hoá thẻ / quyết định
      mirror_service.dart         tab trên máy: đọc + nghe luồng, gửi lệnh (gõ vào tab, giao việc mới)
      notification_service.dart   thông báo có nút
      home_widget_service.dart    dữ liệu của widget màn hình chính + cú chạm vào nút của nó
      background.dart             các điểm vào chạy nền (thông báo đẩy, nút trên thông báo, nút trên widget)
      pairing_store.dart          lưu máy đã ghép
      biometric_service.dart      vân tay / khuôn mặt / mật mã máy
    pages/
      shell/shell_page.dart       khung app: thanh trên, bốn mục ở thanh dưới, vòng đời app
      shell/shell_vm.dart         mục đang mở (provider — màn con cũng chuyển mục được)
      shell/pair_actions.dart     quét / dán mã rồi ghép, dùng chung cho mọi chỗ mở được việc ghép máy
      home/home_vm.dart           ViewModel: HomeState + HomeVm (Notifier) — trạng thái chung của app
      home/home_page.dart         mục Hôm nay (View): vẽ HomeState, chuyển thao tác cho HomeVm
      home/widgets/               mảnh của mục Hôm nay (thẻ chờ, dòng trạng thái, thẻ lần đầu)
      tabs/tabs_page.dart         mục Tab (+ tabs_vm.dart: thanh tab của các máy)
      tabs/tab_vm.dart            ViewModel hội thoại của một tab (+ tab_page.dart)
      tabs/new_task_vm.dart       ViewModel giao việc mới (+ new_task_page.dart)
      activity/activity_page.dart mục Hoạt động
      settings/settings_page.dart mục Cài đặt (+ widgets/: dòng máy đã ghép, mời ghim widget)
      scan/, setup/
    components/                 widget dùng chung (kính, nút, icon 3D, hộp thoại, thanh điều hướng dưới…)
    themes/, constants/
    utils/markdown.dart         lời agent (Markdown) → HTML rút gọn / chữ trơn cho thông báo và widget
```

- **View không tự quyết gì**: nó đọc `ref.watch(homeVmProvider)` và gọi hàm của `HomeVm`. Thứ duy nhất View tự làm là việc
  cần `BuildContext` — hộp thoại, chuyển màn, thanh báo (ViewModel trả về câu cần nói).
- **ViewModel không biết Firebase / mạng**: nó chỉ gọi service qua provider ⇒ test thay service bằng bản giả
  (`test/pages/home/home_vm_test.dart`) — không cần Firebase, không cần widget.
- **Phần chạy nền** (thông báo tới lúc app đã tắt, nút trên thông báo, nút trên widget màn hình chính) là isolate riêng,
  không có cây widget: nó tự dựng một `ProviderContainer` để lấy đúng các service đó (`services/background.dart`).
- Thêm màn mới: `pages/<màn>/<màn>_page.dart` + `<màn>_vm.dart`; thêm nguồn dữ liệu mới: một class trong `services/` kèm
  provider của nó.
