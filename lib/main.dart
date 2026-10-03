import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pairing.dart';
import 'scan_page.dart';
import 'theme.dart';

/// Bow Notify — app đồng hành của bow-agent: CHỈ nhận thông báo đẩy (FCM). Không gọi về máy chạy bow, không duyệt
/// từ xa. Ghép máy = quét mã QR ở web bow (Cài đặt → Thông báo điện thoại) rồi đăng ký topic trong mã.
///
/// App chạy nền / đã tắt: hệ điều hành tự hiện thông báo (FCM gửi kèm khối `notification`). App đang mở: iOS vẫn
/// hiện + kêu; Android thì không — app tự dựng thông báo qua kênh native `bow/notify` (MainActivity.kt).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseError;
  try {
    // Không truyền options: đọc cấu hình native do `flutterfire configure` đặt (google-services.json /
    // GoogleService-Info.plist). Android cần cấu hình native để hiện thông báo cả khi app đã tắt hẳn.
    await Firebase.initializeApp();
  } catch (e) {
    firebaseError = '$e';
  }
  runApp(BowNotifyApp(firebaseError: firebaseError));
}

/// Giao diện theo ngôn ngữ máy: tiếng Việt khi máy đặt tiếng Việt, còn lại tiếng Anh.
String t(String vi, String en) =>
    PlatformDispatcher.instance.locale.languageCode == 'vi' ? vi : en;

const _prefsKey = 'pairings';
const _native = MethodChannel('bow/notify');

/// Một thông báo đã tới lúc app đang mở.
typedef Received = ({String kind, String title, String body, DateTime at});

/// Hình + màu của từng loại thông báo (`data.kind` do server gửi: approval / question / done / fatal / test).
({IconData icon, Color color}) kindLook(String kind, Bow c) => switch (kind) {
  'approval' => (icon: Icons.verified_user_rounded, color: c.accent),
  'question' => (icon: Icons.forum_rounded, color: c.teal),
  'done' => (icon: Icons.check_circle_rounded, color: c.ok),
  'fatal' => (icon: Icons.error_rounded, color: c.danger),
  _ => (icon: Icons.bolt_rounded, color: c.accent),
};

class BowNotifyApp extends StatelessWidget {
  const BowNotifyApp({super.key, this.firebaseError});

  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bow Notify',
      debugShowCheckedModeBanner: false,
      theme: bowTheme(Brightness.light),
      darkTheme: bowTheme(Brightness.dark),
      home: firebaseError == null
          ? const HomePage()
          : SetupNeededPage(error: firebaseError!),
    );
  }
}

/// Khung chung của mọi màn: hình nền Cực quang + thanh trạng thái trong suốt + dòng thương hiệu ở đầu.
class BowScaffold extends StatelessWidget {
  const BowScaffold({
    super.key,
    required this.children,
    this.action,
    this.bottom,
  });

  final List<Widget> children;
  final Widget? action;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Wallpaper(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 14, 6),
                  child: Row(
                    children: [
                      BrandMark(size: 26, color: c.accent),
                      const SizedBox(width: 10),
                      Text(
                        'BOW',
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Notify',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      ?action,
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: children,
                  ),
                ),
                if (bottom != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: bottom,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bản build thiếu cấu hình Firebase — nói rõ phải làm gì thay vì màn hình trắng.
class SetupNeededPage extends StatelessWidget {
  const SetupNeededPage({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return BowScaffold(
      children: [
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Chưa có cấu hình Firebase', 'Firebase is not configured'),
                style: TextStyle(
                  color: c.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t(
                  'Bản build này thiếu google-services.json / GoogleService-Info.plist. Chạy `flutterfire configure` ở gốc repo rồi build lại — xem README.md.',
                  'This build lacks google-services.json / GoogleService-Info.plist. Run `flutterfire configure` at the repo root and rebuild — see README.md.',
                ),
                style: TextStyle(color: c.ink, height: 1.45),
              ),
              const SizedBox(height: 12),
              SelectableText(
                error,
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _messaging = FirebaseMessaging.instance;
  List<Pairing> _pairings = [];

  /// Thông báo tới lúc app đang mở — mới nhất trước.
  final List<Received> _recent = [];
  bool _notifyDenied = false;
  bool _busy = false;
  StreamSubscription<RemoteMessage>? _sub;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getStringList(_prefsKey) ?? [])
        .map(Pairing.parse)
        .nonNulls
        .toList();
    final settings = await _messaging.requestPermission();
    // iOS: cho thông báo hiện + kêu cả khi app đang mở. Android không có lựa chọn này — xem `_onMessage`.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    _sub = FirebaseMessaging.onMessage.listen(_onMessage);
    if (!mounted) return;
    setState(() {
      _pairings = saved;
      _notifyDenied =
          settings.authorizationStatus == AuthorizationStatus.denied;
    });
  }

  /// Tin tới lúc app đang mở: ghi vào "Vừa nhận", và trên Android tự dựng thông báo (đúng kênh ⇒ đúng âm) vì hệ
  /// điều hành không hiện gì khi app ở trước mặt.
  void _onMessage(RemoteMessage message) {
    final note = message.notification;
    if (note == null) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        _native
            .invokeMethod<void>('show', {
              'title': note.title,
              'body': note.body,
              'channel': note.android?.channelId,
              'tag': note.android?.tag ?? message.messageId,
            })
            .catchError((Object _) {}),
      );
    }
    if (!mounted) return;
    setState(
      () => _recent.insert(0, (
        kind: message.data['kind'] as String? ?? '',
        title: note.title ?? '',
        body: note.body ?? '',
        at: DateTime.now(),
      )),
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _pairings.map((p) => p.uri).toList());
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Ghép với máy trong mã: kiểm dự án Firebase khớp với app, đăng ký topic, rồi mới lưu.
  Future<void> _pair(String? raw) async {
    if (raw == null) return;
    final pairing = Pairing.parse(raw);
    if (pairing == null) {
      return _say(
        t('Đây không phải mã ghép của bow.', 'This is not a bow pairing code.'),
      );
    }
    final appProject = Firebase.app().options.projectId;
    if (pairing.projectId != appProject) {
      return _say(
        t(
          'Mã ghép thuộc dự án Firebase "${pairing.projectId}", còn app này build cho "$appProject" — sẽ không nhận được gì. Build lại app với đúng dự án.',
          'This code belongs to Firebase project "${pairing.projectId}" but the app was built for "$appProject" — nothing would arrive. Rebuild the app for that project.',
        ),
      );
    }
    if (_pairings.any((p) => p.topic == pairing.topic)) {
      return _say(
        t('Máy này đã ghép rồi.', 'Already paired with this machine.'),
      );
    }
    setState(() => _busy = true);
    try {
      await _messaging
          .subscribeToTopic(pairing.topic)
          .timeout(const Duration(seconds: 20));
      setState(() => _pairings = [..._pairings, pairing]);
      await _save();
      _say(
        t(
          'Đã ghép với ${pairing.host}. Bấm "Gửi thử" trên web để kiểm.',
          'Paired with ${pairing.host}. Press "Send test" on the web to check.',
        ),
      );
    } catch (e) {
      // iOS chưa có token APNs (thiếu quyền Push / chạy trên máy ảo không hỗ trợ) là lý do hay gặp nhất.
      _say(t('Không đăng ký nhận được: $e', 'Could not subscribe: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpair(Pairing pairing) async {
    final ok = await showGlassDialog<bool>(
      context,
      title: t('Bỏ ghép ${pairing.host}?', 'Unpair ${pairing.host}?'),
      content: Text(
        t(
          'Điện thoại này thôi nhận thông báo từ máy đó.',
          'This phone stops receiving notifications from it.',
        ),
      ),
      actions: (close) => [
        GlassButton(label: t('Thôi', 'Cancel'), onPressed: () => close(false)),
        GlassButton(
          label: t('Bỏ ghép', 'Unpair'),
          kind: GlassButtonKind.danger,
          onPressed: () => close(true),
        ),
      ],
    );
    if (ok != true) return;
    try {
      await _messaging
          .unsubscribeFromTopic(pairing.topic)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return _say(
        t(
          'Không bỏ đăng ký được (cần mạng): $e',
          'Could not unsubscribe (needs network): $e',
        ),
      );
    }
    setState(
      () =>
          _pairings = _pairings.where((p) => p.topic != pairing.topic).toList(),
    );
    await _save();
  }

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScanPage(
          title: t('Quét mã ghép', 'Scan pairing code'),
          hint: t(
            'Đưa camera vào mã QR ở web bow: Cài đặt → Thông báo điện thoại.',
            'Point at the QR code in bow: Settings → Phone notifications.',
          ),
        ),
      ),
    );
    await _pair(raw);
  }

  /// Nhập mã ghép bằng tay (web bow → "Chép mã"): dùng khi không quét được, vd mở web bow trên chính điện thoại này.
  /// Ô nhập thường chứ không tự đọc clipboard — iOS hỏi quyền mỗi lần app tự đọc.
  Future<void> _enterCode() async {
    final input = TextEditingController();
    final raw = await showGlassDialog<String>(
      context,
      title: t('Dán mã ghép', 'Paste pairing code'),
      content: TextField(
        controller: input,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        maxLines: 3,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(hintText: 'bowpush://pair?…'),
      ),
      actions: (close) => [
        GlassButton(label: t('Thôi', 'Cancel'), onPressed: () => close(null)),
        GlassButton(
          label: t('Ghép', 'Pair'),
          kind: GlassButtonKind.primary,
          onPressed: () => close(input.text),
        ),
      ],
    );
    await _pair(raw);
  }

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final paired = _pairings.isNotEmpty;
    return BowScaffold(
      action: IconButton(
        onPressed: _busy ? null : _enterCode,
        tooltip: t('Dán mã ghép', 'Paste pairing code'),
        icon: Icon(Icons.content_paste_rounded, color: c.ink),
      ),
      bottom: SizedBox(
        width: double.infinity,
        child: GlassButton(
          label: _busy
              ? t('Đang ghép…', 'Pairing…')
              : t('Quét mã ghép', 'Scan pairing code'),
          icon: Icons.qr_code_scanner_rounded,
          kind: GlassButtonKind.primary,
          large: true,
          onPressed: _busy ? null : _scan,
        ),
      ),
      children: [
        Glass(
          padding: const EdgeInsets.fromLTRB(12, 14, 18, 14),
          child: Row(
            children: [
              ListeningMark(active: paired && !_notifyDenied),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paired
                          ? t(
                              'Đang nghe ${_pairings.length} máy',
                              'Listening to ${_pairings.length} machine${_pairings.length == 1 ? '' : 's'}',
                            )
                          : t('Chưa ghép máy nào', 'Nothing paired yet'),
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      paired
                          ? t(
                              'Agent chờ bạn duyệt, hỏi bạn, chạy xong hay lỗi — điện thoại báo ngay, mỗi việc một âm riêng.',
                              'Agent waiting, asking, finished or failed — your phone tells you, each with its own sound.',
                            )
                          : t(
                              'Trên web bow mở Cài đặt → Thông báo điện thoại rồi quét mã QR ở đó.',
                              'In bow open Settings → Phone notifications and scan the QR code there.',
                            ),
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_notifyDenied) ...[
          const SizedBox(height: 12),
          Glass(
            tint: c.danger.withValues(alpha: 0.16),
            child: Row(
              children: [
                Icon(Icons.notifications_off_rounded, color: c.danger),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t(
                      'Thông báo đang bị tắt cho app này — bật lại trong Cài đặt của điện thoại.',
                      'Notifications are off for this app — enable them in the phone settings.',
                    ),
                    style: TextStyle(color: c.ink, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (paired) ...[
          _SectionTitle(t('Máy đã ghép', 'Paired machines')),
          for (final pairing in _pairings)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Glass(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    _IconTile(icon: Icons.laptop_mac_rounded, color: c.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pairing.host.isEmpty
                                ? pairing.projectId
                                : pairing.host,
                            style: TextStyle(
                              color: c.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Firebase · ${pairing.projectId}',
                            style: TextStyle(color: c.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _unpair(pairing),
                      tooltip: t('Bỏ ghép', 'Unpair'),
                      icon: Icon(Icons.link_off_rounded, color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (_recent.isNotEmpty) ...[
          _SectionTitle(t('Vừa nhận', 'Just received')),
          Glass(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final (index, item) in _recent.indexed) ...[
                  if (index > 0) Divider(height: 1, color: c.hairline),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        _IconTile(
                          icon: kindLook(item.kind, c).icon,
                          color: kindLook(item.kind, c).color,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: c.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item.body.isNotEmpty)
                                Text(
                                  item.body,
                                  style: TextStyle(
                                    color: c.muted,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          TimeOfDay.fromDateTime(item.at).format(context),
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Bow.of(context).muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

/// Ô vuông bo góc nhuộm màu chứa một icon — kiểu icon nhiều màu của web bow.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, color: color, size: 21),
  );
}

/// Hộp thoại bằng kính. `actions` nhận hàm đóng hộp kèm kết quả.
Future<T?> showGlassDialog<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  required List<Widget> Function(void Function(T? result) close) actions,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0x520A1020),
    builder: (context) {
      final c = Bow.of(context);
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        child: Glass(
          tint: c.isDark
              ? const Color(0xB81B1E32)
              : const Color(
                  0xCCF6F7FB,
                ), // --glass-thick: lớp nổi phải đục hơn tấm thường
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: c.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              DefaultTextStyle.merge(
                style: TextStyle(color: c.ink, fontSize: 14.5, height: 1.45),
                child: content,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: actions((result) => Navigator.pop(context, result)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
