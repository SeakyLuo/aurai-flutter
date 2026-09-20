import '../app/glass_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/chat/glass_surface.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/dialog_action_button.dart';
import 'task_filter_menu.dart';
import 'task_repeat.dart';

Future<TaskRepeat?> showTaskRepeatDialog(
  BuildContext context,
  TaskRepeat value, {
  bool daysOnly = false,
  bool showFrequency = false,
}) => showDialog<TaskRepeat>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: .24),
  builder: (_) => _RepeatDialog(
    value: value,
    daysOnly: daysOnly,
    showFrequency: showFrequency,
  ),
);

class _RepeatDialog extends StatefulWidget {
  const _RepeatDialog({
    required this.value,
    required this.daysOnly,
    required this.showFrequency,
  });
  final TaskRepeat value;
  final bool daysOnly;
  final bool showFrequency;
  @override
  State<_RepeatDialog> createState() => _RepeatDialogState();
}

class _RepeatDialogState extends State<_RepeatDialog> {
  late final TaskRepeat _value = widget.value.copy();
  late final _interval = TextEditingController(text: '${_value.interval}');
  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  void _done() {
    final interval = int.tryParse(_interval.text);
    if (interval == null || interval < 1 || interval > 99) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('间隔请输入 1 到 99')));
      return;
    }
    if (_value.frequency == 'WEEKLY' && _value.weekdays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('至少选择一天')));
      return;
    }
    _value.interval = interval;
    Navigator.pop(context, _value);
  }

  Widget _choice(
    String title,
    String selected,
    String label,
    List<({String value, String label})> options,
    ValueChanged<String> change,
  ) => Builder(
    builder: (rowContext) => Material(
      color: dialogControlColor(context),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            ),
            const SizedBox(width: 4),
            const SizedBox.square(
              dimension: 16,
              child: FittedBox(
                child: SettingsIcon(type: SettingsIconType.chevron),
              ),
            ),
          ],
        ),
        onTap: () async {
          final box = rowContext.findRenderObject()! as RenderBox;
          final result = await showTaskChoiceMenu(
            context,
            anchor: box.localToGlobal(Offset.zero) & box.size,
            selected: selected,
            label: title,
            choices: options,
          );
          if (result != null && mounted) setState(() => change(result));
        },
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 320,
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      child: GlassSurface(
        radius: 28,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '执行',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (widget.showFrequency) ...[
                _choice(
                  '频率',
                  _value.frequency,
                  '每${_value.unit}',
                  const [
                    (value: 'HOURLY', label: '每小时'),
                    (value: 'DAILY', label: '每天'),
                    (value: 'WEEKLY', label: '每周'),
                    (value: 'MONTHLY', label: '每月'),
                  ],
                  (value) => _value.frequency = value,
                ),
                const SizedBox(height: 12),
              ],
              if (!widget.daysOnly) ...[
                Row(
                  children: [
                    const Text('每隔', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: dialogControlColor(context),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: TextField(
                          controller: _interval,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_value.unit, style: const TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (_value.frequency == 'WEEKLY')
                Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        backgroundColor: dialogControlColor(context),
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .55),
                        side: BorderSide.none,
                        label: Text(
                          '周${TaskRepeat.dayNames[day - 1]}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        selected: _value.weekdays.contains(day),
                        showCheckmark: false,
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _value.weekdays.add(day);
                          } else {
                            _value.weekdays.remove(day);
                          }
                        }),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                  ],
                ),
              if (_value.frequency == 'MONTHLY') ...[
                _choice(
                  '按',
                  _value.ordinal == null ? 'date' : 'weekday',
                  _value.ordinal == null ? '日期' : '星期',
                  const [
                    (value: 'date', label: '日期'),
                    (value: 'weekday', label: '星期'),
                  ],
                  (value) => _value.ordinal = value == 'date' ? null : 1,
                ),
                const SizedBox(height: 10),
                if (_value.ordinal == null)
                  _choice(
                    '每月',
                    '${_value.monthDay}',
                    '${_value.monthDay} 日',
                    [
                      for (var day = 1; day <= 31; day++)
                        (value: '$day', label: '$day 日'),
                    ],
                    (value) => _value.monthDay = int.parse(value),
                  )
                else ...[
                  _choice(
                    '第几个',
                    '${_value.ordinal}',
                    _value.ordinal == -1
                        ? '最后一个'
                        : '第${['一', '二', '三', '四', '五'][_value.ordinal! - 1]}个',
                    const [
                      (value: '1', label: '第一个'),
                      (value: '2', label: '第二个'),
                      (value: '3', label: '第三个'),
                      (value: '4', label: '第四个'),
                      (value: '5', label: '第五个'),
                      (value: '-1', label: '最后一个'),
                    ],
                    (value) => _value.ordinal = int.parse(value),
                  ),
                  const SizedBox(height: 10),
                  _choice(
                    '星期',
                    '${_value.weekday}',
                    '周${TaskRepeat.dayNames[_value.weekday - 1]}',
                    [
                      for (var day = 1; day <= 7; day++)
                        (
                          value: '$day',
                          label: '周${TaskRepeat.dayNames[day - 1]}',
                        ),
                    ],
                    (value) => _value.weekday = int.parse(value),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  '当月没有选定日期时跳过该月',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DialogActionButton(
                      text: '取消',
                      role: DialogActionRole.secondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DialogActionButton(
                      text: '完成',
                      onPressed: _done,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
