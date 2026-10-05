import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/glass.dart';
import '../../components/glass_button.dart';
import '../../components/glass_dialog.dart';
import '../../components/section_title.dart';
import '../../components/wallpaper.dart';
import '../../models/mirror.dart';
import '../../themes/bow_theme.dart';
import '../../utils/l10n.dart';
import 'new_task_vm.dart';
import 'tab_page.dart';
import 'tabs_vm.dart';

/// "Giao việc mới" (View): chọn dự án đã đăng ký trên máy, gõ đề bài, hai công tắc — trang bow trên máy mở một tab mới
/// rồi tự gửi đề bài đó. Gửi xong thì sang thẳng hội thoại của tab vừa mở.
class NewTaskPage extends ConsumerStatefulWidget {
  const NewTaskPage({super.key, required this.machine});

  final MachineRef machine;

  @override
  ConsumerState<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends ConsumerState<NewTaskPage> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {})); // nút gửi sáng lên khi có chữ
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Máy không có vân tay / khoá màn hình: hỏi lại bằng một hộp xác nhận — vẫn hơn một cú chạm nhầm.
  Future<bool> _askConfirm(String project, NewTaskState state) async {
    if (!mounted) return false;
    final ok = await showGlassDialog<bool>(
      context,
      title: t('Giao việc mới cho agent?', 'Give the agent a new task?'),
      content: Text(
        [
          if (project.isNotEmpty) t('Dự án: $project.', 'Project: $project.'),
          t(
            'Trang bow trên máy sẽ mở một tab mới và gửi đề bài này cho agent.',
            'The bow page on the machine opens a new tab and sends this prompt to the agent.',
          ),
          if (state.autopilot)
            t(
              'Autopilot BẬT: agent tự commit, đẩy nhánh việc và mở MR.',
              'Autopilot ON: the agent commits, pushes its work branch and opens the MR.',
            )
          else if (state.autoApprove)
            t(
              'Tự duyệt BẬT: thao tác ghi thường tự chạy.',
              'Auto-approve ON: ordinary writes run without asking.',
            ),
        ].join(' '),
      ),
      actions: (close) => [
        GlassButton(label: t('Thôi', 'Cancel'), onPressed: () => close(false)),
        GlassButton(
          label: t('Giao việc', 'Send task'),
          kind: GlassButtonKind.primary,
          onPressed: () => close(true),
        ),
      ],
    );
    return ok == true;
  }

  Future<void> _send(MachineTabs machine, String projectId) async {
    final vm = ref.read(newTaskVmProvider(widget.machine).notifier);
    final state = ref.read(newTaskVmProvider(widget.machine));
    final project = machine.projects
        .where((p) => p.id == projectId)
        .map((p) => p.name)
        .firstOrNull;
    FocusScope.of(context).unfocus();
    final result = await vm.send(
      _input.text,
      projectId: projectId,
      askFallback: () => _askConfirm(project ?? '', state),
    );
    if (!mounted) return;
    final tabId = result.tabId;
    if (tabId == null) {
      if (result.error.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(result.error)));
      }
      return;
    }
    if (tabId.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    // Tab đã mở và đang chạy đề bài: sang thẳng hội thoại của nó (thay màn này — bấm quay lại là về màn chính).
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => TabPage(
          tab: (
            topic: widget.machine.topic,
            port: widget.machine.port,
            tabId: tabId,
          ),
          fresh: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final ref_ = widget.machine;
    final state = ref.watch(newTaskVmProvider(ref_));
    final vm = ref.read(newTaskVmProvider(ref_).notifier);
    final machine = ref
        .watch(tabsVmProvider)
        .where((m) => m.pairing.topic == ref_.topic && m.port == ref_.port)
        .firstOrNull;
    final stale = machine?.stale(DateTime.now()) ?? true;
    final ready = machine != null && machine.canNew && !stale;
    // Dự án đã chọn mà máy vừa gỡ thì quay về dự án chọn sẵn.
    final picked = state.projectId;
    final projectId = machine == null
        ? ''
        : picked != null && machine.projects.any((p) => p.id == picked)
        ? picked
        : defaultProject(machine);
    final label = TextStyle(
      color: c.ink,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    final hint = TextStyle(color: c.muted, fontSize: 12.5, height: 1.35);
    return Scaffold(
      body: Wallpaper(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: t('Quay lại', 'Back'),
                      icon: Icon(Icons.arrow_back_rounded, color: c.ink),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('Giao việc mới', 'New task'),
                            style: TextStyle(
                              color: c.ink,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (machine != null)
                            Text(
                              '${machine.pairing.host}:${machine.port}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.muted, fontSize: 12.5),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    if (machine != null && stale)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: StaleNote(machine: machine),
                      ),
                    if (machine != null && !machine.canNew)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Glass(
                          tint: c.danger.withValues(alpha: 0.14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            t(
                              'Máy này đã tắt quyền giao việc từ điện thoại.',
                              'This machine no longer allows tasks from the phone.',
                            ),
                            style: TextStyle(color: c.ink, fontSize: 13),
                          ),
                        ),
                      ),
                    if (machine != null && machine.projects.isNotEmpty) ...[
                      SectionTitle(t('Dự án', 'Project')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final project in machine.projects)
                            GlassButton(
                              key: ValueKey('project-${project.id}'),
                              label: project.name.isEmpty
                                  ? project.id
                                  : project.name,
                              kind: project.id == projectId
                                  ? GlassButtonKind.primary
                                  : GlassButtonKind.plain,
                              onPressed: state.sending
                                  ? null
                                  : () => vm.pick(project.id),
                            ),
                        ],
                      ),
                    ],
                    SectionTitle(t('Đề bài', 'Prompt')),
                    Glass(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                      child: TextField(
                        key: const ValueKey('prompt'),
                        controller: _input,
                        enabled: !state.sending,
                        minLines: 5,
                        maxLines: 12,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          hintText: t(
                            'Việc cần làm — mã ticket, mô tả lỗi, yêu cầu…',
                            'What to do — a ticket key, a bug, a request…',
                          ),
                          hintStyle: TextStyle(color: c.muted, fontSize: 14.5),
                        ),
                      ),
                    ),
                    SectionTitle(
                      t(
                        'Agent được tự làm tới đâu',
                        'How far the agent may go',
                      ),
                    ),
                    Glass(
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      child: Column(
                        children: [
                          _SwitchRow(
                            key: const ValueKey('auto-approve'),
                            title: t('Tự duyệt', 'Auto-approve'),
                            detail: t(
                              'Thao tác ghi thường tự chạy. Xoá, push, rebase… vẫn dừng hỏi bạn.',
                              'Ordinary writes run on their own. Deletes, pushes, rebases… still stop and ask.',
                            ),
                            value: state.autoApprove,
                            onChanged: state.sending ? null : vm.setAutoApprove,
                            label: label,
                            hint: hint,
                          ),
                          Divider(height: 1, color: c.hairline),
                          _SwitchRow(
                            key: const ValueKey('autopilot'),
                            title: 'Autopilot A–Z',
                            detail: t(
                              'Agent làm một mạch tới khi MR đã mở: tự commit, đẩy nhánh việc, mở MR rồi báo link. Tab chạy ở mode Auto, có trần chi phí.',
                              'The agent runs straight through until the MR is open: commits, pushes its work branch, opens the MR and reports the link. The tab runs in Auto mode with a cost cap.',
                            ),
                            value: state.autopilot,
                            onChanged: state.sending ? null : vm.setAutopilot,
                            label: label,
                            hint: hint,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
                      child: Text(
                        t(
                          'Tab mới dùng model và mode của tab gần nhất cùng dự án. Hai công tắc trên không thừa kế — mỗi việc tự chọn. Thao tác cần duyệt vẫn báo về điện thoại này.',
                          'The new tab uses the model and mode of the most recent tab in the same project. The two switches are never inherited — you choose per task. Anything that needs approval is still sent to this phone.',
                        ),
                        style: hint,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    key: const ValueKey('send'),
                    label: state.sending
                        ? t('Đang gửi tới máy…', 'Sending to the machine…')
                        : t('Giao việc', 'Send task'),
                    icon: state.sending ? null : Icons.send_rounded,
                    kind: GlassButtonKind.primary,
                    large: true,
                    onPressed:
                        ready && !state.sending && _input.text.trim().isNotEmpty
                        ? () => _send(machine, projectId)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.hint,
  });

  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final TextStyle label;
  final TextStyle hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: label),
              const SizedBox(height: 2),
              Text(detail, style: hint),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Bow.of(context).accent,
        ),
      ],
    ),
  );
}
