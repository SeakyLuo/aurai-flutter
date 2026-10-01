import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import '../../storage/private_task_state.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'glass_surface.dart';
import 'header_action_menu.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'task_playback_icon.dart';

class PrivateGoalSheet extends StatefulWidget {
  const PrivateGoalSheet({
    super.key,
    required this.store,
    required this.controller,
    required this.initialState,
    required this.initiallyEditing,
    required this.onControl,
  });
  final PrivateTaskState store;
  final ChatController controller;
  final Map<String, dynamic> initialState;
  final bool initiallyEditing;
  final Future<bool> Function(String) onControl;
  @override
  State<PrivateGoalSheet> createState() => _PrivateGoalSheetState();
}

class _PrivateGoalSheetState extends State<PrivateGoalSheet> {
  late Map<String, dynamic> _goal = widget.initialState;
  late bool _editing = widget.initiallyEditing;
  late final _text = TextEditingController(text: _goal['objective'] as String);
  late final _budget = TextEditingController(
    text: _goal['tokenBudget']?.toString() ?? '',
  );
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  bool _busy = false;
  bool _leaving = false;
  String _originalText = '';
  String _originalBudget = '';
  bool get _dirty =>
      _editing &&
      (_text.text != _originalText || _budget.text != _originalBudget);

  @override
  void initState() {
    super.initState();
    _originalText = _text.text;
    _originalBudget = _budget.text;
    _subscription = widget.store.changes.listen((state) {
      if (mounted) setState(() => _goal = state);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _text.dispose();
    _budget.dispose();
    super.dispose();
  }

  void _edit() {
    _text.text = _goal['objective'] as String;
    _budget.text = _goal['tokenBudget']?.toString() ?? '';
    _originalText = _text.text;
    _originalBudget = _budget.text;
    setState(() => _editing = true);
  }

  Future<bool> _save() async {
    setState(() => _busy = true);
    final ok = await runUiAction(context, () async {
      final value = _budget.text.trim();
      final budget = value.isEmpty ? null : int.tryParse(value);
      if (value.isNotEmpty && (budget == null || budget <= 0)) {
        throw ArgumentError('Token 预算请输入正整数，留空为不限');
      }
      await widget.controller.editPrivateGoal(
        widget.store.conversationId,
        _text.text,
        budget,
      );
    });
    if (!mounted) return false;
    setState(() {
      _busy = false;
      if (ok) _editing = false;
    });
    if (ok) FocusScope.of(context).unfocus();
    return ok;
  }

  Future<void> _back() async {
    if (_busy) return;
    final wasEditing = _editing;
    if (_dirty) {
      final action = await showDialog<String>(
        context: context,
        builder: (_) => TaskUnsavedDialog(
          title: '保存修改？',
          description: '目标还有未保存的修改。',
          canSave: _text.text.trim().isNotEmpty,
        ),
      );
      if (!mounted || action == null || action == 'continue') return;
      if (action == 'save' && !await _save()) return;
      if (action != 'save' && action != 'discard') return;
    }
    if (!mounted) return;
    if (wasEditing) {
      setState(() => _editing = false);
      FocusScope.of(context).unfocus();
    } else {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _more(BuildContext anchor) async {
    final status = _goal['status'];
    final action = await showHeaderActionMenu(
      anchor,
      items: [
        if (status == 'active')
          (
            value: 'pause',
            label: '暂停目标',
            icon: TaskPlaybackIcon(
              paused: false,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        if (['paused', 'blocked', 'budget_limited'].contains(status))
          (
            value: 'resume',
            label: '继续目标',
            icon: const SettingsIcon(type: SettingsIconType.play),
          ),
        (
          value: 'clear',
          label: '清除目标',
          icon: const ConversationMenuIcon(
            type: ConversationMenuIconType.delete,
          ),
        ),
      ],
      destructiveValues: const {'clear'},
    );
    if (!mounted || action == null) return;
    if (action == 'resume') {
      Navigator.pop(context);
      await widget.onControl(action);
      return;
    }
    setState(() => _busy = true);
    final ok = await widget.onControl(action);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && action == 'clear') Navigator.pop(context);
  }

  // Keep field geometry and typography aligned with PersonalInfoPage._profileField.
  Widget _field(
    String label,
    TextEditingController controller,
    String value, {
    bool multiline = false,
  }) => !_editing
      ? _overviewField(label, value, selectable: multiline)
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextField(
              controller: controller,
              enabled: !_busy,
              minLines: multiline ? 3 : 1,
              maxLines: multiline ? 8 : 1,
              keyboardType: multiline
                  ? TextInputType.multiline
                  : TextInputType.number,
              textInputAction: multiline
                  ? TextInputAction.newline
                  : TextInputAction.done,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: multiline ? '希望达成什么目标' : '不限，留空即可',
                filled: true,
                fillColor: settingsFieldColor(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
  Widget _overviewField(
    String label,
    String value, {
    bool selectable = false,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    title: Text(label),
    subtitle: selectable ? SelectableText(value) : Text(value),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: _leaving || (!_editing && !_busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SizedBox(
          height: (MediaQuery.sizeOf(context).height - inset) * .85,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _editing ? 40 : 81,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SettingsGlassAction(
                            label: _editing ? '取消编辑' : '关闭',
                            icon: Icons.close_rounded,
                            iconWidget: const QuestionIcon(
                              type: QuestionIconType.close,
                            ),
                            onPressed: _busy ? null : _back,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _editing ? '编辑目标' : '目标',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SettingsGlassActionSurface(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RoundAction(
                              label: _editing ? '保存' : '编辑目标',
                              icon: Icons.edit_rounded,
                              iconWidget: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : _editing
                                  ? SettingsIcon(
                                      type: SettingsIconType.check,
                                      color:
                                          SettingsGlassAction.foregroundColor(
                                            context,
                                            enabled: _text.text
                                                .trim()
                                                .isNotEmpty,
                                          ),
                                    )
                                  : const ConversationMenuIcon(
                                      type: ConversationMenuIconType.rename,
                                    ),
                              onPressed:
                                  _busy ||
                                      (_editing && _text.text.trim().isEmpty)
                                  ? null
                                  : () async {
                                      if (_editing) {
                                        if (_dirty) {
                                          await _save();
                                        } else {
                                          setState(() => _editing = false);
                                        }
                                      } else {
                                        _edit();
                                      }
                                    },
                            ),
                            if (!_editing) ...[
                              SizedBox(
                                height: 18,
                                child: VerticalDivider(
                                  width: 1,
                                  color: colors.outlineVariant,
                                ),
                              ),
                              Builder(
                                builder: (anchor) => RoundAction(
                                  label: '目标操作',
                                  icon: Icons.more_horiz,
                                  iconWidget: const SettingsIcon(
                                    type: SettingsIconType.more,
                                  ),
                                  onPressed: _busy ? null : () => _more(anchor),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: _editing
                        ? const EdgeInsets.fromLTRB(16, 16, 16, 32)
                        : const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _field(
                        '目标',
                        _text,
                        _goal['objective'] as String? ?? '',
                        multiline: true,
                      ),
                      if (_editing) const SizedBox(height: 16),
                      _field(
                        'Token 预算',
                        _budget,
                        _goal['tokenBudget']?.toString() ?? '不限',
                      ),
                      if (!_editing) ...[
                        _overviewField('状态', switch (_goal['status']) {
                          'active' => '进行中',
                          'paused' => '已暂停',
                          'blocked' => '目标已停滞',
                          'budget_limited' => '预算已用完',
                          'complete' => '已完成',
                          _ => '',
                        }),
                        _overviewField(
                          'Token 用量',
                          _goal['usageIncomplete'] == true
                              ? '用量不完整'
                              : (_goal['tokensUsed'] ?? 0).toString(),
                        ),
                        if ((_goal['reason'] as String? ?? '').isNotEmpty)
                          _overviewField('说明', _goal['reason'] as String),
                      ],
                      if (_editing && _goal['status'] == 'active')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                          child: Text(
                            '保存后暂停当前执行，可从目标菜单继续。',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
