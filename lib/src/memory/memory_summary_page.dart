import '../features/chat/retained_tab_view.dart';
import '../domain/error_message.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/dialog_action_button.dart';
import '../features/chat/search_type_segment.dart';
import 'package:flutter/material.dart';

import '../features/chat/glass_surface.dart';
import '../features/chat/message_composer.dart';
import '../features/chat/keyboard_inset.dart';
import '../features/chat/settings_appearance.dart';
import 'memory_controller.dart';
import 'memory_plan_preview.dart';
import 'memory_processing_border.dart';
import '../providers/responses_transport.dart';
import 'memory_editor.dart';
import 'memory_actions_menu.dart';
import 'memory_entry_tile.dart';
import 'memory_delete_dialog.dart';
import 'memory_toast.dart';

class MemorySummaryPage extends StatefulWidget {
  const MemorySummaryPage({
    super.key,
    required this.memory,
    this.title = '记忆',
    this.groupMemories,
    this.initialGroup = false,
  });
  final MemoryController memory;
  final String title;
  final Widget? groupMemories;
  final bool initialGroup;

  @override
  State<MemorySummaryPage> createState() => _MemorySummaryPageState();
}

class _MemorySummaryPageState extends State<MemorySummaryPage> {
  late bool _group = widget.initialGroup;
  late bool _groupVisited = widget.initialGroup;
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;
  bool _planning = false;
  int _request = 0;
  MemoryPlan? _plan;
  ResponsesTransport? _transport;

  void _cancelPlan() {
    _request++;
    _transport?.cancel();
    _transport = null;
    setState(() {
      _planning = false;
      _plan = null;
    });
  }

  bool _allowPop = false;
  MemoryController get memory => widget.memory;

  @override
  void dispose() {
    _request++;
    _transport?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving) return;
    if (_text.text.trim().isNotEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .24),
        builder: (_) => const DeleteConfirmationDialog(
          title: '放弃未保存的记忆？',
          description: '输入的内容尚未保存。',
          cancelLabel: '继续编辑',
          confirmLabel: '放弃',
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (_planning || _plan != null) _cancelPlan();
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _edit(Map<String, Object?> entry) async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MemoryEditor(memory: memory, entry: entry),
      ),
    );
  }

  Future<void> _menu(Map<String, Object?> entry, Offset position) async {
    final action = await showMemoryActionsMenu(context, position);
    if (!mounted || action == null) return;
    if (action == MemoryAction.edit) {
      await _edit(entry);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => const MemoryDeleteDialog(),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await memory.deleteEntry(entry['id'] as String);
      if (mounted) memoryToast(context, '记忆已删除');
    } on Object catch (error) {
      if (mounted) memoryToast(context, '删除失败，请重试：${errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    final request = ++_request;
    final transport = ResponsesTransport(memory.modelConfig());
    _transport = transport;
    setState(() => _planning = true);
    _focus.unfocus();
    try {
      final plan = await memory.prepareChanges(
        _text.text.trim(),
        transport: transport,
      );
      if (!mounted || request != _request) return;
      if (plan.changes.isEmpty) {
        memoryToast(context, '没有需要调整的记忆，手动保存的内容会保留');
      } else {
        setState(() => _plan = plan);
      }
    } on Object catch (error) {
      if (mounted && request == _request) {
        memoryToast(
          context,
          error is StateError
              ? error.message
              : '无法生成建议，请检查模型配置后重试：${errorMessage(error)}',
        );
      }
    } finally {
      if (mounted && request == _request) {
        _transport = null;
        setState(() => _planning = false);
      }
    }
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      await memory.applyChanges(_plan!);
      if (!mounted) return;
      setState(() => _plan = null);
      _text.clear();
      memoryToast(context, '记忆已更新');
    } on Object catch (error) {
      if (mounted) {
        setState(() => _plan = null);
        memoryToast(
          context,
          error is StateError
              ? error.message
              : '无法应用，请重新整理后重试：${errorMessage(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: memory,
    builder: (context, _) {
      return PopScope(
        canPop: _allowPop || (!_saving && _text.text.trim().isEmpty),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_saving) _leave();
        },
        child: Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: _group ? null : KeyboardInset(child: _footer()),
          appBar: SettingsAppBar(
            title: widget.title,
            gradientBackground: true,
            titleWidget: widget.groupMemories == null
                ? null
                : SearchTypeSegment(
                    files: _group,
                    labels: const ['私聊', '群聊'],
                    onChanged: (group) {
                      if (_saving || _planning) return;
                      _focus.unfocus();
                      setState(() {
                        _group = group;
                        _groupVisited |= group;
                      });
                    },
                  ),
            onBack: _saving ? null : _leave,
          ),
          body: RetainedTabView(
            index: _group ? 1 : 0,
            swipeEnabled: !_saving && !_planning && widget.groupMemories != null,
            onChanged: (index) {
              _focus.unfocus();
              setState(() {
                _group = index == 1;
                _groupVisited |= _group;
              });
            },
            children: [
              Builder(
                builder: (context) => SafeArea(
                  top: false,
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          8,
                          MediaQuery.paddingOf(context).top + 8,
                          8,
                          MediaQuery.paddingOf(context).bottom + 28,
                        ),
                        children: [
                          if (_plan != null)
                            MemoryPlanPreview(plan: _plan!)
                          else ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                memory.entries.isEmpty
                                    ? (memory.scope.isEmpty
                                          ? '这里会逐渐记录对你的了解。你可以在下方补充希望记住的信息。'
                                          : '这里会记录在这个群聊中形成的记忆。你可以在下方补充信息。')
                                    : '以下是对话中形成、或主动保存的记忆。',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                            ),
                            if (memory.entries.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              for (final entry in memory.entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: MemoryEntryTile(
                                    key: ValueKey(entry['id']),
                                    text: entry['text'] as String,
                                    enabled: !_saving && !_planning,
                                    onEdit: () => _edit(entry),
                                    onMenu: (position) =>
                                        _menu(entry, position),
                                  ),
                                ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_groupVisited)
                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + 76,
                  ),
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: widget.groupMemories!,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      );
    },
  );
  Widget _footer() => SafeArea(
    top: false,
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_plan != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: DialogActionButton(
                        text: '取消',
                        liquidGlass: true,
                        role: DialogActionRole.secondary,
                        onPressed: _saving ? null : _cancelPlan,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DialogActionButton(
                        text: _saving ? '正在应用' : '确认应用',
                        liquidGlass: true,
                        onPressed: _saving ? null : _apply,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: MemoryProcessingBorder(
                  active: _planning,
                  child: MessageComposer(
                    embedded: true,
                    controller: _text,
                    focusNode: _focus,
                    enabled: !_saving && !_planning,
                    hintText: '整理或补充记忆',
                    maxLength: 300,
                    onChanged: (_) => setState(() {}),
                    action: RoundAction(
                      inkResponse: false,
                      label: _planning ? '停止整理' : '发送',
                      icon: _planning
                          ? Icons.stop_rounded
                          : Icons.arrow_upward_rounded,
                      primary: true,
                      compact: true,
                      onPressed: _planning
                          ? _cancelPlan
                          : _saving || _text.text.trim().isEmpty
                          ? null
                          : _add,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
