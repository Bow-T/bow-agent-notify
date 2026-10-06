import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/links.dart';
import '../../constants/version.dart';
import '../../models/app_release.dart';
import '../../services/link_service.dart';
import '../../services/prefs_store.dart';
import '../../services/update_service.dart';

/// App đang ở bước nào của việc cập nhật.
enum UpdatePhase {
  /// Chưa hỏi lần nào.
  idle,
  checking,

  /// Đã hỏi: đang là bản mới nhất.
  current,

  /// Có bản mới, chưa tải.
  available,
  downloading,

  /// APK đã tải + kiểm xong, chờ cài.
  ready,

  /// Đã đưa cho trình cài đặt của máy, chờ người dùng bấm ở hộp của máy.
  installing,
}

/// Việc vừa hỏng — View đổi thành câu chữ.
enum UpdateProblem { check, download, conflict, storage, install }

class UpdateState {
  const UpdateState({
    this.auto = true,
    this.phase = UpdatePhase.idle,
    this.release,
    this.inApp = false,
    this.progress = 0,
    this.apkPath,
    this.problem,
    this.detail,
    this.hidden = false,
  });

  /// Tự hỏi bản mới khi mở app (Cài đặt → Về ứng dụng).
  final bool auto;
  final UpdatePhase phase;

  /// Bản mới nhất hỏi được gần đây nhất.
  final AppRelease? release;

  /// Bản đó tải + cài được ngay trong app (Android, bản phát hành có kèm APK). Không thì chỉ mở được trang tải.
  final bool inApp;

  /// Phần đã tải, 0–1.
  final double progress;
  final String? apkPath;
  final UpdateProblem? problem;

  /// Lời của trình cài đặt khi cài hỏng (tiếng Anh của máy) — hiện kèm để người dùng chép lại được.
  final String? detail;

  /// Người dùng đã gạt dải báo ở Hôm nay cho bản này (tới lần mở app sau).
  final bool hidden;

  /// Đang có một bản mới để mời: hiện dải báo ở Hôm nay + chấm ở mục Cài đặt.
  bool get offer => const {
    UpdatePhase.available,
    UpdatePhase.downloading,
    UpdatePhase.ready,
    UpdatePhase.installing,
  }.contains(phase);

  /// Bỏ trống [problem] là XOÁ lỗi cũ: mỗi bước mới bắt đầu sạch.
  UpdateState copyWith({
    bool? auto,
    UpdatePhase? phase,
    AppRelease? release,
    bool? inApp,
    double? progress,
    String? apkPath,
    UpdateProblem? problem,
    String? detail,
    bool? hidden,
  }) => UpdateState(
    auto: auto ?? this.auto,
    phase: phase ?? this.phase,
    release: release ?? this.release,
    inApp: inApp ?? this.inApp,
    progress: progress ?? this.progress,
    apkPath: apkPath ?? this.apkPath,
    problem: problem,
    detail: problem == null ? null : detail,
    hidden: hidden ?? this.hidden,
  );
}

/// Bản mới của app: tự hỏi GitHub khi mở app (tắt được), tải APK và mở trình cài đặt của máy ngay trong app. App
/// KHÔNG tự cài: tải chỉ bắt đầu khi người dùng bấm, và cài luôn qua hộp xác nhận của Android.
class UpdateVm extends Notifier<UpdateState> {
  static const _autoKey = 'update_auto';

  /// Tự hỏi thưa nhất ngần này một lần khi app trở lại màn hình (mở app từ đầu thì luôn hỏi).
  static const autoEvery = Duration(hours: 6);

  DateTime? _checkedAt;

  /// Lần cài đang chờ trả lời — bấm cài lại thì câu trả lời của lần trước bị bỏ.
  var _attempt = 0;

  UpdateService get _service => ref.read(updateServiceProvider);

  @override
  UpdateState build() => const UpdateState();

  /// Nạp lựa chọn "tự kiểm tra" đã lưu (gọi lúc app khởi động).
  Future<void> load() async {
    try {
      final saved = await ref.read(prefsStoreProvider).readInt(_autoKey);
      if (saved != null) state = state.copyWith(auto: saved != 0);
    } catch (_) {
      // Không đọc được: giữ mặc định (bật).
    }
  }

  void setAuto(bool auto) {
    if (auto == state.auto) return;
    state = state.copyWith(
      auto: auto,
      problem: state.problem,
      detail: state.detail,
    );
    unawaited(
      ref
          .read(prefsStoreProvider)
          .writeInt(_autoKey, auto ? 1 : 0)
          .catchError((Object _) {}),
    );
    if (auto) unawaited(autoCheck());
  }

  /// App vừa mở / vừa trở lại màn hình: hỏi bản mới nếu đang bật và lần hỏi trước đã đủ lâu. Hỏng thì im lặng.
  Future<void> autoCheck() async {
    final last = _checkedAt;
    if (!state.auto) return;
    if (last != null && DateTime.now().difference(last) < autoEvery) return;
    await check(silent: true);
  }

  /// Hỏi GitHub bản mới nhất. [silent] = lần hỏi tự động: mất mạng thì không báo lỗi.
  Future<void> check({bool silent = false}) async {
    const busy = {
      UpdatePhase.checking,
      UpdatePhase.downloading,
      UpdatePhase.installing,
    };
    if (busy.contains(state.phase)) return;
    final before = state;
    // Lần hỏi tự động không đổi chữ trên màn hình ("đang kiểm tra…") khi người dùng không bấm gì.
    if (!silent) state = state.copyWith(phase: UpdatePhase.checking);
    final AppRelease release;
    try {
      release = await _service.latest();
      // Chỉ lần hỏi ĐƯỢC mới tính vào nhịp tự hỏi: mở app lúc mạng chưa kịp lên thì lần trở lại app kế tiếp hỏi lại.
      _checkedAt = DateTime.now();
    } catch (_) {
      if (ref.mounted && !silent) {
        state = before.copyWith(problem: UpdateProblem.check);
      }
      return;
    }
    if (!ref.mounted) return;
    // Lần hỏi tự động chạy ngầm: trong lúc chờ người dùng có thể đã bấm tải — khi đó bỏ kết quả này.
    final was = silent ? state : before;
    if (silent && busy.contains(was.phase)) return;
    final sameRelease = was.release?.tag == release.tag;
    if (!isNewerVersion(release.version, appVersion)) {
      state = UpdateState(
        auto: was.auto,
        phase: UpdatePhase.current,
        release: release,
      );
    } else if (was.phase == UpdatePhase.ready && sameRelease) {
      // Bản này đã tải sẵn rồi — giữ nguyên, khỏi tải lại.
      state = was.copyWith(
        problem: silent ? was.problem : null,
        detail: was.detail,
      );
    } else {
      state = UpdateState(
        auto: was.auto,
        phase: UpdatePhase.available,
        release: release,
        inApp: _service.canInstall && release.hasApk,
        // Vẫn là bản đã gạt đi thì đừng hiện lại dải báo trong lần mở app này.
        hidden: was.hidden && sameRelease,
        // Lần hỏi ngầm không xoá dòng lỗi người dùng đang đọc (vd "tải hỏng").
        problem: silent && sameRelease ? was.problem : null,
        detail: silent && sameRelease ? was.detail : null,
      );
    }
  }

  /// Nút chính của bản mới khi cài được trong app: chưa tải thì tải rồi mở trình cài đặt; đã tải thì mở trình cài
  /// đặt (bấm lại lúc đang chờ = mở lại hộp của máy).
  Future<void> update() async {
    final release = state.release;
    if (release == null || !state.inApp) return;
    switch (state.phase) {
      case UpdatePhase.available:
        await _download(release);
      case UpdatePhase.ready || UpdatePhase.installing:
        await _install();
      default:
        return;
    }
  }

  Future<void> _download(AppRelease release) async {
    state = state.copyWith(phase: UpdatePhase.downloading, progress: 0);
    final String path;
    try {
      path = await _service.download(
        release,
        onProgress: (received, total) {
          // Mỗi phần trăm một lần vẽ lại — không phải mỗi mẩu dữ liệu.
          final progress = (received * 100 ~/ total) / 100;
          if (ref.mounted && progress != state.progress) {
            state = state.copyWith(progress: progress);
          }
        },
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: UpdatePhase.available,
        problem: UpdateProblem.download,
      );
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(phase: UpdatePhase.ready, apkPath: path);
    await _install();
  }

  Future<void> _install() async {
    final path = state.apkPath;
    if (path == null) return;
    final attempt = ++_attempt;
    state = state.copyWith(phase: UpdatePhase.installing);
    ({InstallResult result, String? message}) reply;
    try {
      reply = await _service.install(path);
    } catch (e) {
      reply = (result: InstallResult.failed, message: '$e');
    }
    if (!ref.mounted || attempt != _attempt) return;
    final problem = switch (reply.result) {
      InstallResult.done || InstallResult.cancelled => null,
      InstallResult.conflict => UpdateProblem.conflict,
      InstallResult.storage => UpdateProblem.storage,
      InstallResult.failed => UpdateProblem.install,
    };
    state = state.copyWith(
      phase: UpdatePhase.ready,
      problem: problem,
      detail: reply.message,
    );
  }

  /// Gạt dải báo ở Hôm nay ("để sau"). Chấm ở mục Cài đặt vẫn còn.
  void hide() => state = state.copyWith(
    hidden: true,
    problem: state.problem,
    detail: state.detail,
  );

  /// Mở trang tải bằng trình duyệt: lối DUY NHẤT trên iPhone / khi bản phát hành không kèm APK, và lối dự phòng khi
  /// cập nhật trong app hỏng. `false` = máy không mở được trình duyệt.
  Future<bool> openDownloadLink() =>
      ref.read(linkServiceProvider).open(downloadLink);

  /// Android có APK thì là link tải thẳng file; còn lại là trang phát hành.
  String get downloadLink =>
      _service.canInstall && (state.release?.hasApk ?? true)
      ? latestApkUrl
      : releasesPageUrl;
}

final updateVmProvider = NotifierProvider<UpdateVm, UpdateState>(UpdateVm.new);
