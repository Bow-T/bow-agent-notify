import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pairing.dart';
import 'scan_page.dart';

/// Bow Notify — app đồng hành của bow-agent: CHỈ nhận thông báo đẩy (FCM). Không gọi về máy chạy bow, không duyệt
/// từ xa. Ghép máy = quét mã QR ở web bow (Cài đặt → Thông báo điện thoại) rồi đăng ký topic trong mã.
///
/// Thông báo lúc app chạy nền / đã tắt do hệ điều hành tự hiện (FCM gửi kèm khối `notification`); lúc app đang mở
/// thì hiện trong danh sách "Vừa nhận".
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseError;
  try {
    // Không truyền options: đọc cấu hình native do `flutterfire configure` đặt (google-services.json /
    // GoogleService-Info.plist) — repo không chứa cấu hình Firebase của ai cả.
    await Firebase.initializeApp();
  } catch (e) {
    firebaseError = '$e';
  }
  runApp(BowNotifyApp(firebaseError: firebaseError));
}

/// Giao diện theo ngôn ngữ máy: tiếng Việt khi máy đặt tiếng Việt, còn lại tiếng Anh.
String t(String vi, String en) => PlatformDispatcher.instance.locale.languageCode == 'vi' ? vi : en;

const _prefsKey = 'pairings';

class BowNotifyApp extends StatelessWidget {
  const BowNotifyApp({super.key, this.firebaseError});

  final String? firebaseError;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFB8862B);
    return MaterialApp(
      title: 'Bow Notify',
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: firebaseError == null ? const HomePage() : SetupNeededPage(error: firebaseError!),
    );
  }
}

/// App chưa có cấu hình Firebase (chưa chạy `flutterfire configure`) — nói rõ phải làm gì thay vì màn hình trắng.
class SetupNeededPage extends StatelessWidget {
  const SetupNeededPage({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bow Notify')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(t('Chưa có cấu hình Firebase', 'Firebase is not configured'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(t(
            'Chạy `flutterfire configure` ở gốc repo này với dự án Firebase mà bow đang dùng, rồi build lại app. Xem README.md.',
            'Run `flutterfire configure` at the root of this repo against the Firebase project bow sends through, then rebuild. See README.md.',
          )),
          const SizedBox(height: 16),
          SelectableText(error, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
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

  /// Thông báo tới lúc app đang mở (hệ điều hành không tự hiện) — mới nhất trước.
  final List<({RemoteNotification note, DateTime at})> _recent = [];
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
    final saved = (prefs.getStringList(_prefsKey) ?? []).map(Pairing.parse).nonNulls.toList();
    final settings = await _messaging.requestPermission();
    // iOS: cho thông báo hiện cả khi app đang mở (Android không có lựa chọn này — dùng danh sách "Vừa nhận").
    await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    _sub = FirebaseMessaging.onMessage.listen((message) {
      final note = message.notification;
      if (note == null || !mounted) return;
      setState(() => _recent.insert(0, (note: note, at: DateTime.now())));
    });
    if (!mounted) return;
    setState(() {
      _pairings = saved;
      _notifyDenied = settings.authorizationStatus == AuthorizationStatus.denied;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _pairings.map((p) => p.uri).toList());
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Ghép với máy trong mã: kiểm dự án Firebase khớp với app, đăng ký topic, rồi mới lưu.
  Future<void> _pair(String? raw) async {
    if (raw == null) return;
    final pairing = Pairing.parse(raw);
    if (pairing == null) {
      return _say(t('Đây không phải mã ghép của bow.', 'This is not a bow pairing code.'));
    }
    final appProject = Firebase.app().options.projectId;
    if (pairing.projectId != appProject) {
      return _say(t(
        'Mã ghép thuộc dự án Firebase "${pairing.projectId}", còn app này build cho "$appProject" — sẽ không nhận được gì. Build lại app với đúng dự án.',
        'This code belongs to Firebase project "${pairing.projectId}" but the app was built for "$appProject" — nothing would arrive. Rebuild the app for that project.',
      ));
    }
    if (_pairings.any((p) => p.topic == pairing.topic)) {
      return _say(t('Máy này đã ghép rồi.', 'Already paired with this machine.'));
    }
    setState(() => _busy = true);
    try {
      await _messaging.subscribeToTopic(pairing.topic).timeout(const Duration(seconds: 20));
      setState(() => _pairings = [..._pairings, pairing]);
      await _save();
      _say(t('Đã ghép với ${pairing.host}. Bấm "Gửi thử" trên web để kiểm.', 'Paired with ${pairing.host}. Press "Send test" on the web to check.'));
    } catch (e) {
      // iOS chưa có token APNs (thiếu quyền Push / chạy trên máy ảo không hỗ trợ) là lý do hay gặp nhất.
      _say(t('Không đăng ký nhận được: $e', 'Could not subscribe: $e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpair(Pairing pairing) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Bỏ ghép ${pairing.host}?', 'Unpair ${pairing.host}?')),
        content: Text(t('Điện thoại này thôi nhận thông báo từ máy đó.', 'This phone stops receiving notifications from it.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Thôi', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('Bỏ ghép', 'Unpair'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _messaging.unsubscribeFromTopic(pairing.topic).timeout(const Duration(seconds: 20));
    } catch (e) {
      return _say(t('Không bỏ đăng ký được (cần mạng): $e', 'Could not unsubscribe (needs network): $e'));
    }
    setState(() => _pairings = _pairings.where((p) => p.topic != pairing.topic).toList());
    await _save();
  }

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScanPage(
          title: t('Quét mã ghép', 'Scan pairing code'),
          hint: t('Đưa camera vào mã QR ở web bow: Cài đặt → Thông báo điện thoại.', 'Point at the QR code in bow: Settings → Phone notifications.'),
        ),
      ),
    );
    await _pair(raw);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    await _pair(data?.text ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bow Notify'),
        actions: [
          IconButton(onPressed: _busy ? null : _paste, tooltip: t('Dán mã ghép', 'Paste pairing code'), icon: const Icon(Icons.content_paste)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _scan,
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(t('Quét mã ghép', 'Scan pairing code')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          if (_notifyDenied)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  t('Thông báo đang bị tắt cho app này — bật lại trong Cài đặt của điện thoại.', 'Notifications are off for this app — enable them in the phone settings.'),
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          Text(t('Máy đã ghép', 'Paired machines'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          if (_pairings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t(
                'Chưa ghép máy nào. Trên web bow mở Cài đặt → Thông báo điện thoại, rồi quét mã QR ở đó (hoặc bấm "Chép mã" và dán vào đây).',
                'Nothing paired yet. In bow open Settings → Phone notifications and scan the QR code there (or "Copy code" and paste it here).',
              )),
            ),
          for (final pairing in _pairings)
            Card(
              child: ListTile(
                leading: const Icon(Icons.computer),
                title: Text(pairing.host.isEmpty ? pairing.projectId : pairing.host),
                subtitle: Text('Firebase: ${pairing.projectId}'),
                trailing: IconButton(onPressed: () => _unpair(pairing), tooltip: t('Bỏ ghép', 'Unpair'), icon: const Icon(Icons.link_off)),
              ),
            ),
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(t('Vừa nhận', 'Just received'), style: theme.textTheme.titleMedium),
            for (final item in _recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(item.note.title ?? ''),
                subtitle: Text(item.note.body ?? ''),
                trailing: Text(TimeOfDay.fromDateTime(item.at).format(context)),
              ),
          ],
        ],
      ),
    );
  }
}
