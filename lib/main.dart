import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'notifications.dart';
import 'pairing.dart';
import 'remote.dart';
import 'scan_page.dart';
import 'store.dart';
import 'theme.dart';
import 'version.dart';

/// Bow Notify — app đồng hành của bow-agent: CHỈ nhận thông báo đẩy (FCM). Không gọi về máy chạy bow, không duyệt
/// từ xa. Ghép máy = quét mã QR ở web bow (Cài đặt → Thông báo điện thoại) rồi đăng ký topic trong mã.
///
/// App chạy nền / đã tắt: hệ điều hành tự hiện thông báo (FCM gửi kèm khối `notification`). App đang mở: iOS vẫn
/// hiện + kêu; Android thì không — app tự dựng thông báo (notifications.dart), kèm nút duyệt khi đó là một thẻ.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseError;
  try {
    // Không truyền options: đọc cấu hình native do `flutterfire configure` đặt (google-services.json /
    // GoogleService-Info.plist). Android cần cấu hình native để hiện thông báo cả khi app đã tắt hẳn.
    await Firebase.initializeApp();
    // Thông báo tới lúc app đang nền / đã tắt: nâng nó thành bản có nút duyệt (notifications.dart).
    FirebaseMessaging.onBackgroundMessage(pushInBackground);
    await initNotifications();
  } catch (e) {
    firebaseError = '$e';
  }
  runApp(BowNotifyApp(firebaseError: firebaseError));
}

/// Giao diện theo ngôn ngữ máy: tiếng Việt khi máy đặt tiếng Việt, còn lại tiếng Anh.
String t(String vi, String en) =>
    PlatformDispatcher.instance.locale.languageCode == 'vi' ? vi : en;

/// Một thông báo đã tới lúc app đang mở.
typedef Received = ({String kind, String title, String body, DateTime at});

/// Icon 3D của từng loại thông báo (`data.kind` do server gửi: approval / question / done / fatal / test) — cùng hình
/// với web bow: khiên = chờ duyệt, bong bóng = đang hỏi, bi xanh = xong, bi đỏ = lỗi.
String kindIcon(String kind) => switch (kind) {
  'approval' => 'shield',
  'question' => 'chat',
  'done' => 'success',
  'fatal' => 'error',
  _ => 'bolt',
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
                      const Icon3d('logo_mark', size: 36),
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
                      const SizedBox(width: 8),
                      // Số phiên bản: biết máy đang cài bản nào mà không phải vào Cài đặt của điện thoại.
                      Text(
                        'v$appVersion',
                        style: TextStyle(color: c.muted, fontSize: 12),
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _messaging = FirebaseMessaging.instance;
  List<Pairing> _pairings = [];

  /// Thẻ đang chờ trên các máy cho duyệt từ điện thoại (remote.dart) — cũ nhất trước.
  List<PendingCard> _pending = [];

  /// Thẻ đang gửi quyết định (khoá nút), và thẻ vừa gửi xong (ẩn tạm tới khi máy chạy bow gỡ nó).
  final Set<String> _sending = {};
  final Map<String, DateTime> _answeredAt = {};
  Timer? _pendingTimer;
  StreamSubscription<RemoteMessage>? _openedSub;

  /// Thông báo tới lúc app đang mở — mới nhất trước.
  final List<Received> _recent = [];
  bool _notifyDenied = false;
  bool _busy = false;
  StreamSubscription<RemoteMessage>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    notificationOpened.addListener(_onNotificationOpened);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    notificationOpened.removeListener(_onNotificationOpened);
    _pendingTimer?.cancel();
    _openedSub?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final saved = await loadPairings();
    final settings = await _messaging.requestPermission();
    // iOS: cho thông báo hiện + kêu cả khi app đang mở. Android không có lựa chọn này — xem `_onMessage`.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    _sub = FirebaseMessaging.onMessage.listen(_onMessage);
    // Bấm vào thông báo để mở app: đọc ngay thẻ đang chờ.
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      (_) => unawaited(_refreshPending()),
    );
    if (!mounted) return;
    setState(() {
      _pairings = saved;
      _notifyDenied =
          settings.authorizationStatus == AuthorizationStatus.denied;
    });
    _watchPending();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _watchPending();
    } else {
      _pendingTimer
          ?.cancel(); // app khuất thì thôi hỏi — thông báo đẩy sẽ gọi dậy
      _pendingTimer = null;
    }
  }

  /// Bấm vào một thông báo (hoặc vừa duyệt bằng nút trên thông báo): đọc lại thẻ chờ ngay.
  void _onNotificationOpened() => unawaited(_refreshPending());

  /// Đọc thẻ chờ ngay, rồi hỏi lại mỗi 4 giây chừng nào app còn ở trước mặt và có máy cho duyệt.
  void _watchPending() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    unawaited(_refreshPending());
    if (!_pairings.any((p) => p.canApprove)) return;
    _pendingTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_refreshPending()),
    );
  }

  Future<void> _refreshPending() async {
    final sources = _pairings.where((p) => p.canApprove).toList();
    final asOf = DateTime.now();
    var complete = true;
    // Một máy không đọc được (mất mạng) không được làm mất thẻ của máy khác.
    final results = await Future.wait(
      sources.map(
        (p) => fetchPending(p).catchError((Object _) {
          complete = false;
          return <PendingCard>[];
        }),
      ),
    );
    if (!mounted) return;
    final now = DateTime.now();
    // Thẻ vừa trả lời: ẩn 15 giây chờ máy chạy bow áp + gỡ. Quá hạn mà còn đó thì hiện lại (bow chưa nhận).
    _answeredAt.removeWhere(
      (_, at) => now.difference(at) > const Duration(seconds: 15),
    );
    final cards = [
      for (final list in results)
        for (final card in list)
          if (!_answeredAt.containsKey(card.id)) card,
    ];
    if (cards.length != _pending.length ||
        !Iterable<int>.generate(
          cards.length,
        ).every((i) => cards[i].id == _pending[i].id)) {
      setState(() => _pending = cards);
    }
    // Thẻ đã xử lý (vừa bấm trong app, hoặc ở web) thì gỡ luôn thông báo có nút của nó. Chỉ khi đọc được MỌI máy —
    // đọc hụt một máy mà gỡ là mất thông báo của thẻ còn đang chờ.
    if (complete) {
      unawaited(dismissHandledCards({for (final card in cards) card.id}, asOf));
    }
  }

  /// Thao tác rủi ro: xác thực bằng vân tay / khuôn mặt / mật mã máy trước khi gửi "cho phép". Máy không có khoá
  /// màn hình thì hỏi lại bằng một hộp xác nhận — vẫn hơn một cú chạm nhầm.
  Future<bool> _confirmRisky(PendingCard card) async {
    final auth = LocalAuthentication();
    try {
      if (await auth.isDeviceSupported()) {
        return await auth.authenticate(
          localizedReason: t(
            'Xác nhận để cho phép thao tác rủi ro trên ${card.pairing.host}',
            'Confirm to allow a risky action on ${card.pairing.host}',
          ),
        );
      }
    } catch (_) {
      // chưa đặt khoá màn hình / chưa đăng ký sinh trắc → rơi xuống hộp xác nhận
    }
    if (!mounted) return false;
    final ok = await showGlassDialog<bool>(
      context,
      title: t('Cho phép thao tác rủi ro?', 'Allow a risky action?'),
      content: Text(card.text, maxLines: 8, overflow: TextOverflow.ellipsis),
      actions: (close) => [
        GlassButton(label: t('Thôi', 'Cancel'), onPressed: () => close(false)),
        GlassButton(
          label: t('Cho phép', 'Allow'),
          kind: GlassButtonKind.danger,
          onPressed: () => close(true),
        ),
      ],
    );
    return ok == true;
  }

  /// Gửi quyết định cho một thẻ: `{allow: bool}` hoặc `{answers: {...} | null}`.
  Future<void> _decide(PendingCard card, Map<String, Object?> reply) async {
    if (_sending.contains(card.id)) return;
    if (card.risky && reply['allow'] == true && !await _confirmRisky(card)) {
      return;
    }
    setState(() => _sending.add(card.id));
    try {
      await sendReply(card, reply);
      _answeredAt[card.id] = DateTime.now();
      if (mounted) {
        setState(
          () => _pending = _pending.where((c) => c.id != card.id).toList(),
        );
        unawaited(
          _refreshPending(),
        ); // gỡ luôn thông báo có nút của thẻ vừa trả lời
      }
    } catch (e) {
      _say(
        t(
          'Không gửi được ($e). Thẻ này có thể đã được trả lời, hoặc bow không còn chạy.',
          'Could not send ($e). The card may already be answered, or bow is no longer running.',
        ),
      );
    } finally {
      if (mounted) setState(() => _sending.remove(card.id));
    }
  }

  /// Tin tới lúc app đang mở: ghi vào "Vừa nhận", và trên Android tự dựng thông báo (đúng kênh ⇒ đúng âm) vì hệ
  /// điều hành không hiện gì khi app ở trước mặt.
  void _onMessage(RemoteMessage message) {
    final note = message.notification;
    if (note == null) return;
    unawaited(_refreshPending());
    // Android không tự hiện gì khi app đang mở: tự dựng thông báo (có nút duyệt nếu là một thẻ).
    unawaited(handlePush(message, foreground: true));
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

  Future<void> _save() => savePairings(_pairings);

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
    final existing = _pairings.indexWhere((p) => p.topic == pairing.topic);
    if (existing >= 0) {
      if (_pairings[existing].uri == pairing.uri) {
        return _say(
          t('Máy này đã ghép rồi.', 'Already paired with this machine.'),
        );
      }
      // Cùng máy nhưng mã MỚI — web vừa bật / tắt "duyệt từ điện thoại" (mã có thêm / mất khoá) hay đổi tên máy:
      // thay bản đã lưu. Topic không đổi nên khỏi đăng ký lại; không làm thế thì phải bỏ ghép rồi quét lại mới có khoá.
      setState(() => _pairings = [..._pairings]..[existing] = pairing);
      await _save();
      _watchPending();
      return _say(
        pairing.canApprove
            ? t(
                'Đã cập nhật ${pairing.host}: giờ duyệt được từ điện thoại này.',
                'Updated ${pairing.host}: you can now approve from this phone.',
              )
            : t(
                'Đã cập nhật ${pairing.host}: chỉ nhận thông báo.',
                'Updated ${pairing.host}: notifications only.',
              ),
      );
    }
    setState(() => _busy = true);
    try {
      await _messaging
          .subscribeToTopic(pairing.topic)
          .timeout(const Duration(seconds: 20));
      setState(() => _pairings = [..._pairings, pairing]);
      await _save();
      _watchPending();
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
    _watchPending();
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
        icon: const Icon3d('clipboard', size: 28),
      ),
      bottom: SizedBox(
        width: double.infinity,
        child: GlassButton(
          label: _busy
              ? t('Đang ghép…', 'Pairing…')
              : t('Quét mã ghép', 'Scan pairing code'),
          // Icon phẳng màu trắng, không phải 3D: hình 3D có màu riêng nên chìm trên nền lam của nút (luật của bộ icon web).
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
                const Icon3d('warning', size: 30),
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
        if (_pending.isNotEmpty) ...[
          _SectionTitle(
            t(
              'Chờ bạn duyệt · ${_pending.length}',
              'Waiting for you · ${_pending.length}',
            ),
          ),
          for (final card in _pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PendingCardView(
                key: ValueKey(card.id),
                card: card,
                busy: _sending.contains(card.id),
                onDecide: (reply) => _decide(card, reply),
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
                    const Icon3d('agent', size: 38),
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
                            pairing.canApprove
                                ? t(
                                    'Firebase · ${pairing.projectId} · duyệt được từ đây',
                                    'Firebase · ${pairing.projectId} · can approve here',
                                  )
                                : 'Firebase · ${pairing.projectId}',
                            style: TextStyle(color: c.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _unpair(pairing),
                      tooltip: t('Bỏ ghép', 'Unpair'),
                      icon: const Icon3d('trash', size: 26),
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
                        Icon3d(kindIcon(item.kind), size: 36),
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

/// Một thẻ đang chờ trên máy chạy bow: xin duyệt (Cho phép / Từ chối) hoặc câu hỏi (chọn đáp án rồi Gửi).
class PendingCardView extends StatefulWidget {
  const PendingCardView({
    super.key,
    required this.card,
    required this.busy,
    required this.onDecide,
  });

  final PendingCard card;
  final bool busy;

  /// `{allow: bool}` cho thẻ duyệt; `{answers: {câu hỏi: nhãn đã chọn} | null}` cho câu hỏi (null = bỏ qua);
  /// `{say: câu}` cho lời mời trả lời.
  final void Function(Map<String, Object?> reply) onDecide;

  @override
  State<PendingCardView> createState() => _PendingCardViewState();
}

class _PendingCardViewState extends State<PendingCardView> {
  /// Đáp án đang chọn: câu hỏi → các nhãn.
  final Map<String, Set<String>> _picks = {};

  bool _picked(Question q, String label) =>
      _picks[q.question]?.contains(label) ?? false;

  void _toggle(Question q, String label) {
    setState(() {
      final picks = _picks.putIfAbsent(q.question, () => {});
      if (!q.multiSelect) {
        picks
          ..clear()
          ..add(label);
      } else if (!picks.remove(label)) {
        picks.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final card = widget.card;
    final isQuestion = card.kind == 'question';
    final isReply = card.kind == 'reply';
    final answered = card.questions.every(
      (q) => _picks[q.question]?.isNotEmpty ?? false,
    );
    final onDecide = widget.busy ? null : widget.onDecide;
    return Glass(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon3d(
                isReply
                    ? 'success'
                    : isQuestion
                    ? 'chat'
                    : 'shield',
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.label.isEmpty ? t('Tác vụ', 'Task') : card.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        if (card.pairing.host.isNotEmpty) card.pairing.host,
                        if (card.tool.isNotEmpty) card.tool,
                        TimeOfDay.fromDateTime(card.at).format(context),
                      ].join(' · '),
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (card.risky) ...[
                const Icon3d('warning', size: 22),
                const SizedBox(width: 4),
                Text(
                  t('Rủi ro', 'Risky'),
                  style: TextStyle(
                    color: c.danger,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (!isQuestion)
            // Lệnh / file cần duyệt: chữ đều nét trong ô lõm, cuộn được khi dài.
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 190),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.well,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.hairline),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  card.text,
                  style: TextStyle(
                    color: c.ink,
                    fontSize: isReply ? 14 : 13,
                    height: 1.4,
                    // Lệnh thì chữ đều nét; lời agent (thẻ trả lời) là văn xuôi.
                    fontFamily: isReply ? null : 'monospace',
                    fontFamilyFallback: isReply
                        ? null
                        : const ['Menlo', 'Courier'],
                  ),
                ),
              ),
            )
          else
            for (final q in card.questions) ...[
              Text(
                q.question,
                style: TextStyle(
                  color: c.ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              for (final option in q.options)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.busy ? null : () => _toggle(q, option.label),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 7,
                      horizontal: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ô chọn phẳng một màu (như bộ tiện ích của web): phải đổi màu theo trạng thái.
                        Icon(
                          switch ((_picked(q, option.label), q.multiSelect)) {
                            (true, true) => Icons.check_box_rounded,
                            (true, false) => Icons.radio_button_checked_rounded,
                            (false, true) =>
                              Icons.check_box_outline_blank_rounded,
                            (false, false) =>
                              Icons.radio_button_unchecked_rounded,
                          },
                          size: 22,
                          color: _picked(q, option.label) ? c.accent : c.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.label,
                                style: TextStyle(color: c.ink, fontSize: 14.5),
                              ),
                              if (option.description.isNotEmpty)
                                Text(
                                  option.description,
                                  style: TextStyle(
                                    color: c.muted,
                                    fontSize: 12.5,
                                    height: 1.35,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
            ],
          const SizedBox(height: 12),
          if (isReply)
            // Lời mời trả lời: mỗi câu một nút — bấm là tab trên máy gửi đúng câu đó. Không có "từ chối": không
            // chọn gì thì lượt cứ nằm đó như khi bạn rời bàn.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, option) in card.options.indexed)
                  GlassButton(
                    label: widget.busy ? t('Đang gửi…', 'Sending…') : option,
                    kind: i == 0
                        ? GlassButtonKind.primary
                        : GlassButtonKind.plain,
                    onPressed: onDecide == null
                        ? null
                        : () => onDecide({'say': option}),
                  ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: isQuestion
                        ? t('Bỏ qua', 'Skip')
                        : t('Từ chối', 'Deny'),
                    onPressed: onDecide == null
                        ? null
                        : () => onDecide(
                            isQuestion ? {'answers': null} : {'allow': false},
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassButton(
                    label: widget.busy
                        ? t('Đang gửi…', 'Sending…')
                        : isQuestion
                        ? t('Gửi', 'Send')
                        : t('Cho phép', 'Allow'),
                    // Vân tay = icon phẳng trắng trên nền lam (hình 3D chìm trên nền màu nhấn).
                    icon: card.risky ? Icons.fingerprint_rounded : null,
                    kind: GlassButtonKind.primary,
                    onPressed: onDecide == null || (isQuestion && !answered)
                        ? null
                        : () => onDecide(
                            isQuestion
                                ? {
                                    'answers': {
                                      for (final q in card.questions)
                                        q.question: _picks[q.question]!.join(
                                          ', ',
                                        ),
                                    },
                                  }
                                : {'allow': true},
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
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
