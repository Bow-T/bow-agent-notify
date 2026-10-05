import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/mirror.dart';
import '../../services/biometric_service.dart';
import '../../services/mirror_service.dart';
import '../../utils/l10n.dart';
import 'tab_vm.dart';
import 'tabs_vm.dart';
import 'typing_gate.dart';

/// Trạng thái màn "Giao việc mới".
@immutable
class NewTaskState {
  const NewTaskState({
    this.projectId,
    this.autoApprove = false,
    this.autopilot = false,
    this.sending = false,
  });

  /// Dự án đã chọn (`null` = chưa chọn, màn hình tự chọn dự án của tab đang mở).
  final String? projectId;

  /// Hai công tắc quyết định agent tự làm được bao nhiêu khi không ai trông. Mặc định TẮT — không thừa kế từ tab nào.
  final bool autoApprove;
  final bool autopilot;
  final bool sending;

  NewTaskState copyWith({
    String? projectId,
    bool? autoApprove,
    bool? autopilot,
    bool? sending,
  }) => NewTaskState(
    projectId: projectId ?? this.projectId,
    autoApprove: autoApprove ?? this.autoApprove,
    autopilot: autopilot ?? this.autopilot,
    sending: sending ?? this.sending,
  );
}

/// Dự án chọn sẵn khi mở màn: dự án của tab đang mở trên máy (nếu còn trong danh sách), không thì dự án đầu tiên.
/// Máy không dùng dự án thì rỗng (thư mục mặc định).
String defaultProject(MachineTabs machine) {
  if (machine.projects.isEmpty) return '';
  final active = machine.tabs
      .where((tab) => tab.id == machine.active)
      .firstOrNull
      ?.projectId;
  return machine.projects.any((p) => p.id == active)
      ? active!
      : machine.projects.first.id;
}

/// ViewModel "Giao việc mới" cho MỘT trang bow: chọn dự án, hai công tắc, rồi gửi đề bài để trang đó mở tab mới.
class NewTaskVm extends Notifier<NewTaskState> {
  NewTaskVm(this.machine);

  final MachineRef machine;

  @override
  NewTaskState build() => const NewTaskState();

  void pick(String projectId) => state = state.copyWith(projectId: projectId);
  void setAutoApprove(bool on) => state = state.copyWith(autoApprove: on);
  void setAutopilot(bool on) => state = state.copyWith(autopilot: on);

  /// Gửi đề bài. Trả `tabId` của tab vừa mở khi thành công; `error` khi không (rỗng = người dùng tự huỷ ở bước xác
  /// thực, không có gì để báo). Giao việc mới LUÔN hỏi vân tay — không dùng phiên mở khoá 5 phút của ô gõ.
  Future<({String? tabId, String error})> send(
    String text, {
    required String projectId,
    required Future<bool> Function() askFallback,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty || state.sending) return (tabId: null, error: '');
    final pairing = ref
        .read(mirrorPairingsProvider)
        .where((p) => p.topic == machine.topic)
        .firstOrNull;
    if (pairing == null) return (tabId: null, error: sayFailure('denied'));
    final confirmed =
        await ref
            .read(biometricServiceProvider)
            .confirm(
              t(
                'Xác nhận để giao việc mới cho agent',
                'Confirm to give the agent a new task',
              ),
            ) ??
        await askFallback();
    if (!confirmed || !ref.mounted) return (tabId: null, error: '');
    state = state.copyWith(sending: true);
    try {
      final result = await ref
          .read(mirrorServiceProvider)
          .newTask(
            pairing,
            machine.port,
            projectId: projectId,
            text: clean,
            autoApprove: state.autoApprove,
            autopilot: state.autopilot,
          );
      if (!result.ok) return (tabId: null, error: sayFailure(result.reason));
      // Vừa xác thực xong: mở luôn phiên gõ để câu tiếp theo trong tab mới khỏi hỏi lại.
      ref.read(typingGateProvider.notifier).unlockNow();
      return (tabId: result.tabId, error: '');
    } catch (e) {
      return (
        tabId: null,
        error: t('Không gửi được: $e', 'Could not send: $e'),
      );
    } finally {
      if (ref.mounted) state = state.copyWith(sending: false);
    }
  }
}

final newTaskVmProvider =
    NotifierProvider.family<NewTaskVm, NewTaskState, MachineRef>(
      NewTaskVm.new,
      isAutoDispose: true,
    );
