import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/glass.dart';
import '../../components/icon3d.dart';
import '../../components/row_tile.dart';
import '../../components/sub_page.dart';
import '../../constants/links.dart';
import '../../services/link_service.dart';
import '../../themes/bow_theme.dart';
import '../../utils/l10n.dart';

/// Cài đặt → Hướng dẫn: mỗi việc app làm được một thẻ ngắn — có gì, và phải bật gì ở web bow.
class GuidePage extends ConsumerWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Bow.of(context);
    final topics = [
      (
        icon: 'qr',
        title: t('Ghép máy', 'Pair a machine'),
        body: t(
          'Trên web bow mở Cài đặt → Thông báo điện thoại, rồi bấm nút quét ở góc trên của app và đưa camera vào mã QR. Mở web bow ngay trên điện thoại này thì bấm "Chép mã" ở web và dán trong màn quét.',
          'In bow open Settings → Phone notifications, then press the scan button at the top of the app and point at the QR code. If bow is open on this phone, press "Copy code" there and paste it in the scan screen.',
        ),
      ),
      (
        icon: 'shield',
        title: t('Duyệt từ điện thoại', 'Approve from the phone'),
        body: t(
          'Cần bật "Duyệt từ điện thoại" ở web bow rồi quét LẠI mã. Thẻ agent chờ hiện ở mục Hôm nay, trên thông báo, và trên widget. Thao tác rủi ro phải qua vân tay.',
          'Turn on "Approve from phone" in bow and scan the code AGAIN. Cards show up in Today, on notifications and on the widget. Risky actions need your fingerprint.',
        ),
      ),
      (
        icon: 'layers',
        title: t('Xem tab và gõ tiếp', 'See tabs and keep typing'),
        body: t(
          'Bật "Xem tab và hội thoại trên điện thoại" (và "Cho gõ vào tab" nếu muốn ra lệnh). Mục Tab hiện các tab của trang bow; chạm một tab để đọc và gõ. Trang bow trên máy phải còn mở.',
          'Turn on "View tabs and conversations on the phone" (and "Allow typing into tabs" to send prompts). The Tabs section lists the tabs of bow; tap one to read and type. bow must stay open on the machine.',
        ),
      ),
      (
        icon: 'bolt',
        title: t('Giao việc mới', 'Start a new task'),
        body: t(
          'Ở mục Tab bấm "Giao việc mới", chọn dự án và gõ đề bài — trang bow mở một tab mới và chạy. Lần nào cũng hỏi vân tay.',
          'In Tabs press "New task", pick a project and type the prompt — bow opens a new tab and runs it. This always asks for your fingerprint.',
        ),
      ),
      (
        icon: 'drop',
        title: t('Giao diện', 'Appearance'),
        body: t(
          'Cài đặt → Giao diện: hai theme của web bow (Kính, Brutal), chế độ sáng / tối, và ngôn ngữ.',
          'Settings → Appearance: the two bow themes (Glass, Brutal), light / dark mode, and language.',
        ),
      ),
      (
        icon: 'warning',
        title: t('Không thấy thông báo?', 'No notifications?'),
        body: t(
          'Mở Cài đặt → Chẩn đoán: nó thử lại từng chặng và chỉ ra chặng nào hỏng. Lần đầu sau khi ghép có thể chậm tới một phút.',
          'Open Settings → Diagnostics: it retries each step and shows which one fails. The first notification after pairing can take up to a minute.',
        ),
      ),
    ];
    return SubPage(
      title: t('Hướng dẫn', 'Guide'),
      children: [
        for (final topic in topics)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Glass(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon3d(topic.icon, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          topic.title,
                          style: TextStyle(
                            color: c.ink,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic.body,
                    style: TextStyle(
                      color: c.ink,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        RowTile(
          icon: 'info',
          title: t('Tài liệu đầy đủ', 'Full documentation'),
          subtitle: 'github.com/$releasesRepo',
          onTap: () => ref.read(linkServiceProvider).open(readmeUrl),
        ),
      ],
    );
  }
}
