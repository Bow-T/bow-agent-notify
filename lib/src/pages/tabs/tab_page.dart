import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/glass.dart';
import '../../components/icon3d.dart';
import '../../components/markdown_text.dart';
import '../../components/wallpaper.dart';
import '../../models/mirror.dart';
import '../../themes/bow_theme.dart';
import '../../utils/l10n.dart';
import 'tab_vm.dart';
import 'tabs_vm.dart';

String _clock(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

/// Hội thoại của một tab trên máy — CHỈ XEM (View). Mở ra ở cuối, nơi có dòng mới nhất.
class TabPage extends ConsumerStatefulWidget {
  const TabPage({super.key, required this.tab});

  final TabRef tab;

  @override
  ConsumerState<TabPage> createState() => _TabPageState();
}

class _TabPageState extends ConsumerState<TabPage> with WidgetsBindingObserver {
  TabVm get _vm => ref.read(tabVmProvider(widget.tab).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      state == AppLifecycleState.resumed ? _vm.resumed() : _vm.paused();

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final tab = widget.tab;
    final state = ref.watch(tabVmProvider(tab));
    // Tên tab, đang chạy hay không, trang web còn sống không: đọc từ thanh tab của máy đó.
    final machine = ref
        .watch(tabsVmProvider)
        .where((m) => m.pairing.topic == tab.topic && m.port == tab.port)
        .firstOrNull;
    final meta = machine?.tabs.where((t) => t.id == tab.tabId).firstOrNull;
    final stale = machine?.stale(DateTime.now()) ?? false;
    final items = state.items.reversed.toList();
    final spinner = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: c.accent),
    );
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
                            meta == null
                                ? t('Tab đã đóng', 'Tab closed')
                                : meta.title.isEmpty
                                ? t('Tab mới', 'New tab')
                                : meta.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.ink,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              if (meta != null && meta.project.isNotEmpty)
                                meta.project,
                              if (machine != null) machine.pairing.host,
                              t('chỉ xem', 'read-only'),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    if (meta?.running == true) spinner,
                  ],
                ),
              ),
              if (stale && machine != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: StaleNote(machine: machine),
                ),
              Expanded(
                child: !state.loaded
                    ? Center(child: spinner)
                    : items.isEmpty
                    ? Center(
                        child: Text(
                          t(
                            'Tab này chưa có hội thoại.',
                            'This tab has no conversation yet.',
                          ),
                          style: TextStyle(color: c.muted),
                        ),
                      )
                    : ListView.builder(
                        // Đảo chiều: mở ra ở dòng mới nhất, dòng mới tới thì vẫn đứng ở cuối.
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                        itemCount: items.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ChatLine(
                            key: ValueKey(items[index].id),
                            item: items[index],
                          ),
                        ),
                      ),
              ),
              if (meta != null && meta.pending > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Glass(
                      tint: c.accent.withValues(alpha: 0.16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon3d('shield', size: 26),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t(
                                'Tab này đang chờ bạn (${meta.pending}) — về màn chính để duyệt.',
                                'This tab is waiting for you (${meta.pending}) — go back to approve.',
                              ),
                              style: TextStyle(color: c.ink, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
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

/// "Trang bow trên máy không còn báo về" — dữ liệu đang hiện là bản cuối cùng nhận được.
class StaleNote extends StatelessWidget {
  const StaleNote({super.key, required this.machine});

  final MachineTabs machine;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    return Glass(
      tint: c.danger.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon3d('warning', size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(
                'Trang bow trên ${machine.pairing.host} không báo về từ ${_clock(machine.at)} — trang đã đóng hoặc máy đã ngủ. Đây là bản cuối cùng nhận được.',
                'The bow page on ${machine.pairing.host} has not reported since ${_clock(machine.at)} — it is closed or the machine is asleep. This is the last copy received.',
              ),
              style: TextStyle(color: c.ink, fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng của hội thoại: đề bài (bong bóng lệch phải), lời agent (Markdown), dòng tool (một dòng chữ đều nét),
/// lỗi (đỏ), dòng hệ thống / kết quả lượt (mờ).
class ChatLine extends StatelessWidget {
  const ChatLine({super.key, required this.item});

  final MirrorItem item;

  @override
  Widget build(BuildContext context) {
    final c = Bow.of(context);
    final small = TextStyle(color: c.muted, fontSize: 12, height: 1.35);
    switch (item.kind) {
      case 'user':
        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.84,
            ),
            child: Glass(
              tint: c.accent.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              child: SelectableText(
                item.text,
                style: TextStyle(color: c.ink, fontSize: 14, height: 1.4),
              ),
            ),
          ),
        );
      case 'agent':
        return Glass(
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lời của agent phụ không phải câu trả lời cho người dùng — ghi rõ ai nói.
              if (item.sub.isNotEmpty || item.side.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    [
                      if (item.side.isNotEmpty) item.side,
                      if (item.sub.isNotEmpty)
                        '${t('AGENT PHỤ', 'SUBAGENT')} · ${item.sub}',
                    ].join(' · '),
                    style: small.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              MarkdownText(item.text),
            ],
          ),
        );
      case 'tool':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            [
              if (item.sub.isNotEmpty) '↳ ${item.sub} ·',
              item.toolName,
              if (item.toolSummary.isNotEmpty) item.toolSummary,
            ].join(' '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: item.toolError ? c.danger : c.muted,
              fontSize: 12,
              height: 1.35,
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Menlo', 'Courier'],
            ),
          ),
        );
      case 'error':
        return Glass(
          tint: c.danger.withValues(alpha: 0.14),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: SelectableText(
            item.text,
            style: TextStyle(color: c.ink, fontSize: 13.5, height: 1.4),
          ),
        );
      default: // result / system
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(item.text, style: small),
        );
    }
  }
}
