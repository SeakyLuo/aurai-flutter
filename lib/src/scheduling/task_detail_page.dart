import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/chat/chat_controller.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'task_filter_menu.dart';
import 'task_repeat.dart';
import 'task_repeat_dialog.dart';
import '../features/chat/glass_surface.dart';
import 'scheduled_tasks.dart';
import 'task_action_menu.dart';
import 'task_unsaved_dialog.dart';
import 'task_datetime_dialog.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.controller,
    required this.id,
    this.returnConversationId,
  });
  final ChatController controller;
  final String id;
  final String? returnConversationId;
  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late Map<String, Object?> _saved;
  late final TextEditingController _title;
  late final TextEditingController _prompt;
  late DateTime _at;
  late String _rule;
  final _titleFocus = FocusNode();
  final _repeatKey = GlobalKey();
  bool _repeatMenuOpen = false;
  bool _scheduleChanged = false;
  bool _busy = false;
  bool _saving = false;
  bool _leaving = false;
  ScheduledTasks get tasks => widget.controller.scheduledTasks;
  bool get _dirty =>
      _title.text != _saved['title'] ||
      _prompt.text != _saved['prompt'] ||
      _scheduleChanged;
  TaskRepeat? get _recurrence => TaskRepeat.parse(_rule, _at);
  bool get _simple => _rule.isEmpty || _recurrence != null;
  String get _repeat =>
      _rule.isEmpty ? '从不' : _recurrence?.frequencyLabel ?? '自定义';
  String get _repeatKeyValue {
    final value = _recurrence;
    if (_rule.isEmpty) return 'never';
    if (value == null || value.interval != 1 || value.ordinal != null)
      return 'custom';
    return value.workdays ? 'workdays' : value.frequency;
  }

  @override
  void initState() {
    super.initState();
    _saved = Map.of(tasks.tasks.firstWhere((task) => task['id'] == widget.id));
    _title = TextEditingController(text: _saved['title'] as String);
    _prompt = TextEditingController(text: _saved['prompt'] as String);
    _resetSchedule();
  }

  void _resetSchedule() {
    _at = DateTime.fromMillisecondsSinceEpoch(_saved['runAt'] as int);
    _rule = _saved['rrule'] as String;
    _scheduleChanged = false;
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _title.dispose();
    _prompt.dispose();
    super.dispose();
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showGlassSnackBar(SnackBar(content: Text(text)));

  Future<bool> _save() async {
    if (_title.text.trim().isEmpty || _prompt.text.trim().isEmpty) {
      _notice('请填写任务标题和内容');
      return false;
    }
    if (_scheduleChanged && !_at.isAfter(DateTime.now())) {
      _notice('请选择未来的执行时间');
      return false;
    }
    setState(() {
      _busy = true;
      _saving = true;
    });
    try {
      final label =
          _recurrence?.label(_at) ?? taskTime(_at.millisecondsSinceEpoch);
      final result = await tasks.save({
        'id': widget.id,
        'title': _title.text.trim(),
        'prompt': _prompt.text.trim(),
        'scheduleChanged': _scheduleChanged,
        'runAt': _scheduleChanged
            ? _at.millisecondsSinceEpoch
            : _saved['runAt'],
        'rrule': _rule,
        'timezone': _scheduleChanged ? tasks.timezone : _saved['timezone'],
        'scheduleLabel': _scheduleChanged ? label : _saved['scheduleLabel'],
      });
      if (!mounted) return true;
      setState(() {
        _saved = Map.of(result);
        _title.text = result['title'] as String;
        _prompt.text = result['prompt'] as String;
        _resetSchedule();
      });
      _notice('任务已保存');
      return true;
    } on Object catch (e) {
      if (mounted)
        _notice(
          e is PlatformException
              ? e.message ?? '保存失败：${errorMessage(e)}'
              : '保存失败，请重试：${errorMessage(e)}',
        );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  Future<bool> _resolveChanges() async {
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .24),
      builder: (_) => const TaskUnsavedDialog(),
    );
    if (!mounted || choice == null) return false;
    if (choice == 'save') return _save();
    setState(() {
      _title.text = _saved['title'] as String;
      _prompt.text = _saved['prompt'] as String;
      _resetSchedule();
    });
    return true;
  }

  Future<void> _close() async {
    if (_busy || !await _resolveChanges() || !mounted) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _action(String action, Map<String, Object?> task) async {
    if (action != 'delete' && !await _resolveChanges()) return;
    if (!mounted) return;
    if (action == 'conversation') {
      setState(() => _leaving = true);
      if (widget.returnConversationId != null) {
        if (widget.controller.activeConversation.id !=
            widget.returnConversationId) {
          try {
            await widget.controller.selectConversation(
              widget.returnConversationId!,
            );
          } on Object catch (error) {
            if (mounted) {
              setState(() => _leaving = false);
              _notice('无法返回原会话：${errorMessage(error)}');
            }
            return;
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
        return;
      }
      await openTaskConversation(context, widget.controller, task);
      if (mounted) setState(() => _leaving = false);
      return;
    }
    setState(() => _busy = true);
    final success = await manageTask(context, tasks, widget.id, action);
    if (!mounted) return;
    setState(() => _busy = false);
    if (success && action == 'delete') {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _applyRepeat(TaskRepeat value) {
    if (value.rule == _rule || value.rule == _recurrence?.rule) return;
    setState(() {
      _rule = value.rule;
      _at = value.firstStart(_at, DateTime.now());
      _scheduleChanged = true;
    });
  }

  Future<void> _repeatPicker() async {
    final box = _repeatKey.currentContext!.findRenderObject()! as RenderBox;
    setState(() => _repeatMenuOpen = true);
    final result = await showTaskChoiceMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      label: '重复',
      selected: _repeatKeyValue,
      choices: const [
        (value: 'HOURLY', label: '每小时'),
        (value: 'DAILY', label: '每天'),
        (value: 'workdays', label: '工作日'),
        (value: 'WEEKLY', label: '每周'),
        (value: 'MONTHLY', label: '每月'),
        (value: 'custom', label: '自定义'),
        (value: 'never', label: '从不'),
      ],
    );
    if (!mounted) return;
    setState(() => _repeatMenuOpen = false);
    if (result == null) return;
    if (result == 'never') {
      if (_rule.isNotEmpty)
        setState(() {
          _rule = '';
          _scheduleChanged = true;
        });
      return;
    }
    if (result == 'custom') {
      final value = await showTaskRepeatDialog(
        context,
        _recurrence ??
            TaskRepeat(
              frequency: 'DAILY',
              weekdays: {_at.weekday},
              monthDay: _at.day,
              weekday: _at.weekday,
            ),
        showFrequency: true,
      );
      if (mounted && value != null) _applyRepeat(value);
      return;
    }
    if (result == _repeatKeyValue) return;
    _applyRepeat(
      TaskRepeat(
        frequency: result == 'workdays' ? 'WEEKLY' : result,
        weekdays: result == 'workdays' ? {1, 2, 3, 4, 5} : {_at.weekday},
        monthDay: _at.day,
        weekday: _at.weekday,
      ),
    );
  }

  Future<void> _schedulePicker() async {
    if (_rule.isEmpty) {
      await _datePicker();
      return;
    }
    final recurrence = _recurrence;
    if (recurrence == null) {
      _notice('当前为特殊计划，可在重复中选择自定义重新设置');
      return;
    }
    final result = await showTaskRepeatDialog(
      context,
      recurrence,
      daysOnly:
          recurrence.frequency == 'WEEKLY' || recurrence.frequency == 'MONTHLY',
    );
    if (mounted && result != null) _applyRepeat(result);
  }

  Future<void> _datePicker() async {
    if (!_simple) {
      _notice('请先在重复中选择新的执行周期');
      return;
    }
    final result = await showTaskDateTimeDialog(
      context,
      initial: _at,
      timeOnly: false,
    );
    if (result != null && mounted)
      setState(() {
        _at = DateTime(
          result.year,
          result.month,
          result.day,
          _at.hour,
          _at.minute,
        );
        _scheduleChanged = true;
      });
  }

  Future<void> _timePicker() async {
    if (!_simple) {
      _notice('请先在重复中选择新的执行周期');
      return;
    }
    final result = await showTaskDateTimeDialog(
      context,
      initial: _at,
      timeOnly: true,
    );
    if (result != null && mounted)
      setState(() {
        _at = DateTime(
          _at.year,
          _at.month,
          _at.day,
          result.hour,
          result.minute,
        );
        final recurrence = _recurrence;
        if (recurrence != null)
          _at = recurrence.firstStart(_at, DateTime.now());
        _scheduleChanged = true;
      });
  }

  Widget _group(List<Widget> children) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
  TextStyle get _taskTextStyle =>
      Theme.of(context).textTheme.bodyLarge!.copyWith(
        inherit: false,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurface,
      );

  Widget _row(
    String title,
    String value,
    VoidCallback? onTap, {
    bool expanded = false,
    bool dropdown = false,
  }) => ListTile(
    contentPadding: const EdgeInsets.fromLTRB(20, 2, 14, 2),
    title: Text(title, style: _taskTextStyle),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * .43,
          ),
          child: Text(
            value,
            maxLines: 2,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: _taskTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 4),
        AnimatedRotation(
          turns: dropdown ? (expanded ? -.25 : .25) : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          child: const SizedBox.square(
            dimension: 16,
            child: FittedBox(
              child: SettingsIcon(type: SettingsIconType.chevron),
            ),
          ),
        ),
      ],
    ),
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tasks,
    builder: (context, _) {
      final matches = tasks.tasks.where((task) => task['id'] == widget.id);
      final task = matches.isEmpty ? _saved : matches.first;
      final running = ['starting', 'running'].contains(task['state']);
      final enabled = !_saving && !running && matches.isNotEmpty;
      final state = task['state'] as String;
      final control = running
          ? 'stop'
          : state == 'paused'
          ? 'resume'
          : 'pause';
      return PopScope(
        canPop: _leaving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 76,
            leadingWidth: 72,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: SettingsGlassAction(
                  label: '返回',
                  icon: Icons.arrow_back_rounded,
                  onPressed: _busy ? null : _close,
                ),
              ),
            ),
            actions: [
              GlassSurface(
                radius: 28,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dirty)
                      RoundAction(
                        icon: Icons.check_rounded,
                        iconWidget: Opacity(
                          opacity: enabled ? 1 : .3,
                          child: const SettingsIcon(
                            type: SettingsIconType.check,
                          ),
                        ),
                        label: _saving ? '正在保存' : '保存任务',
                        onPressed: enabled && !_busy ? () => _save() : null,
                      )
                    else if (running ||
                        state == 'paused' ||
                        state == 'scheduled')
                      RoundAction(
                        icon: Icons.pause,
                        iconWidget: TaskActionIcon(control),
                        label: running
                            ? '停止执行'
                            : state == 'paused'
                            ? '恢复任务'
                            : '暂停任务',
                        onPressed: _busy ? null : () => _action(control, task),
                      ),
                    Builder(
                      builder: (buttonContext) => RoundAction(
                        icon: Icons.more_vert,
                        iconWidget: const TaskActionIcon('more'),
                        label: '更多',
                        onPressed: _busy
                            ? null
                            : () async {
                                final box =
                                    buttonContext.findRenderObject()!
                                        as RenderBox;
                                final action = await showTaskActionMenu(
                                  context,
                                  box.localToGlobal(Offset(0, box.size.height)),
                                  task,
                                  showEdit: false,
                                  showPauseResume: _dirty,
                                );
                                if (mounted && action != null)
                                  await _action(action, task);
                              },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    _group([
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 60),
                        child: Center(
                          child: TextField(
                            controller: _title,
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            focusNode: _titleFocus,
                            textAlignVertical: TextAlignVertical.center,
                            enabled: enabled,
                            maxLength: 80,
                            style: _taskTextStyle,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: '任务标题',
                              isDense: true,
                              counterText: '',
                              filled: false,
                              contentPadding: EdgeInsets.fromLTRB(20, 0, 14, 0),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      Divider(
                        height: 2,
                        thickness: 2,
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * .4,
                        ),
                        child: TextField(
                          controller: _prompt,
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          enabled: enabled,
                          minLines: 1,
                          maxLines: null,
                          maxLength: 4000,
                          style: _taskTextStyle,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: '任务内容',
                            counterText: '',
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _group([
                      SizedBox(
                        key: _repeatKey,
                        child: _row(
                          '重复',
                          _repeat,
                          enabled ? _repeatPicker : null,
                          expanded: _repeatMenuOpen,
                          dropdown: true,
                        ),
                      ),
                      Divider(
                        height: 2,
                        thickness: 2,
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      _row(
                        '执行',
                        _rule.isEmpty
                            ? '${_at.year}/${_at.month}/${_at.day}'
                            : _recurrence?.executionLabel ??
                                  _saved['scheduleLabel'] as String,
                        enabled ? _schedulePicker : null,
                      ),
                      Divider(
                        height: 2,
                        thickness: 2,
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      _row(
                        _saved['timezone'] == tasks.timezone ? '时间' : '时间（本机）',
                        TimeOfDay.fromDateTime(_at).format(context),
                        enabled ? _timePicker : null,
                      ),
                    ]),
                    if (task['lastError'] != null)
                      TextButton(
                        onPressed: () => _notice(task['lastError'] as String),
                        child: const Text('查看未完成原因'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
