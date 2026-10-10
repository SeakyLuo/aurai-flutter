import 'dart:async';
import '../features/chat/contacts_search_bar.dart';
import '../features/chat/sidebar_action_icon.dart';
import 'memory_source_list.dart';
import '../app/glass_notice.dart';
import '../widgets/empty_data_view.dart';
import '../domain/error_message.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/dialog_action_button.dart';
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
    this.onOpenSource,
    this.actions = const [],
  });
  final MemoryController memory;
  final String title;
  final OpenMemorySource? onOpenSource;
  final List<Widget> actions;

  @override
  State<MemorySummaryPage> createState() => _MemorySummaryPageState();
}

class _MemorySummaryPageState extends State<MemorySummaryPage> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;
  String _searchValue = '';
  Timer? _searchTimer;
  bool _loadingMore = false;
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;
  bool _planning = false;
  int _request = 0;
  MemoryPlan? _plan;
  ResponsesTransport? _transport;

  @override
  void initState() {
    super.initState();
    _search.text = memory.searchQuery;
    _searching = _search.text.isNotEmpty;
    _searchValue = _search.text;
    _search.addListener(_searchChanged);
    _searchMemories(_search.text);
  }

  void _searchChanged() {
    if (_searchValue == _search.text) return;
    _searchValue = _search.text;
    _searchTimer?.cancel();
    _searchTimer = Timer(
      const Duration(milliseconds: 250),
      () => _searchMemories(_search.text),
    );
  }

  void _toggleSearch() {
    if (_searching) {
      _searchFocus.unfocus();
      _search.clear();
      _searchTimer?.cancel();
      setState(() => _searching = false);
      _searchMemories('');
    } else {
      _focus.unfocus();
      setState(() => _searching = true);
    }
  }

  Future<void> _searchMemories(String value) async {
    try {
      memory.searchQuery = value;
      await memory.reload();
    } on Object catch (error) {
      if (mounted)
        memoryToast(context, error.toString(), kind: ToastKind.error);
    }
  }

  Future<void> _more() async {
    setState(() => _loadingMore = true);
    try {
      await memory.loadMore();
    } on Object catch (error) {
      if (mounted)
        memoryToast(context, error.toString(), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

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
    _searchTimer?.cancel();
    _search.removeListener(_searchChanged);
    _search.dispose();
    _searchFocus.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving) return;
    if (_searching) {
      _toggleSearch();
      return;
    }
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
        builder: (_) => MemoryEditor(
          memory: memory,
          entry: entry,
          onOpenSource: widget.onOpenSource,
        ),
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
      if (mounted) memoryToast(context, '记忆已删除', kind: ToastKind.success);
    } on Object catch (error) {
      if (mounted)
        memoryToast(
          context,
          '删除失败，请重试：${errorMessage(error)}',
          kind: ToastKind.error,
        );
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
          kind: ToastKind.error,
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
      memoryToast(context, '记忆已更新', kind: ToastKind.success);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _plan = null);
        memoryToast(
          context,
          error is StateError
              ? error.message
              : '无法应用，请重新整理后重试：${errorMessage(error)}',
          kind: ToastKind.error,
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
        canPop:
            _allowPop || (!_searching && !_saving && _text.text.trim().isEmpty),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_saving) _leave();
        },
        child: Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: KeyboardInset(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                IgnorePointer(
                  ignoring: _searching,
                  child: ExcludeSemantics(
                    excluding: _searching,
                    child: AnimatedSlide(
                      offset: _searching ? const Offset(0, 1.5) : Offset.zero,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      child: _footer(),
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: !_searching,
                  child: ExcludeSemantics(
                    excluding: !_searching,
                    child: AnimatedSlide(
                      offset: _searching ? Offset.zero : const Offset(0, 1.5),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      onEnd: () {
                        if (_searching) _searchFocus.requestFocus();
                      },
                      child: Center(
                        heightFactor: 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: ContactsSearchBar(
                            controller: _search,
                            focusNode: _searchFocus,
                            hintText: '搜索记忆、人物或关键词',
                            onClose: _toggleSearch,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          appBar: SettingsAppBar(
            title: widget.title,
            actions: [
              ...widget.actions,
              SettingsGlassAction(
                label: _searching ? '关闭搜索' : '搜索记忆',
                icon: Icons.search_rounded,
                iconWidget: const SidebarActionIcon(
                  type: SidebarActionIconType.search,
                ),
                onPressed: _saving || _planning || _plan != null
                    ? null
                    : _toggleSearch,
              ),
            ],

            onBack: _saving ? null : _leave,
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: settingsPagePadding(
                    context,
                    EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      130 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                  ),
                  children: [
                    if (_plan != null)
                      MemoryPlanPreview(plan: _plan!)
                    else if (memory.entries.isEmpty)
                      EmptyDataView(
                        title: _search.text.isEmpty ? '还没有记忆' : '没有找到相关记忆',
                        description: _search.text.isEmpty
                            ? '聊天和任务中的有用信息会留在这里，也可以在下方补充。'
                            : '换一个名字或关键词试试。',
                      )
                    else ...[
                      for (final entry in memory.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: MemoryEntryTile(
                            key: ValueKey(entry['id']),
                            text: entry['text'] as String,
                            enabled: !_saving && !_planning,
                            onEdit: () => _edit(entry),
                            onMenu: (position) => _menu(entry, position),
                          ),
                        ),
                      if (memory.hasMore)
                        TextButton(
                          onPressed: _loadingMore ? null : _more,
                          child: Text(_loadingMore ? '正在加载' : '更多记忆'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
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
