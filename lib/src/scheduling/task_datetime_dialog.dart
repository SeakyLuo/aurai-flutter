import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../features/chat/glass_surface.dart';
import '../features/chat/dialog_action_button.dart';

Future<DateTime?> showTaskDateTimeDialog(
  BuildContext context, {
  required DateTime initial,
  required bool timeOnly,
}) => showDialog<DateTime>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: .24),
  builder: (_) => _TaskDateTimeDialog(initial: initial, timeOnly: timeOnly),
);

class _TaskDateTimeDialog extends StatefulWidget {
  const _TaskDateTimeDialog({required this.initial, required this.timeOnly});
  final DateTime initial;
  final bool timeOnly;

  @override
  State<_TaskDateTimeDialog> createState() => _TaskDateTimeDialogState();
}

class _TaskDateTimeDialogState extends State<_TaskDateTimeDialog> {
  late DateTime _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GlassSurface(
          radius: 28,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.timeOnly ? '选择时间' : '选择日期',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: widget.timeOnly
                      ? SizedBox(
                          height: 216,
                          child: CupertinoTheme(
                            data: CupertinoThemeData(
                              brightness: Theme.of(context).brightness,
                              primaryColor: colors.primary,
                              textTheme: CupertinoTextThemeData(
                                dateTimePickerTextStyle: TextStyle(
                                  fontSize: 22,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.time,
                              initialDateTime: widget.initial,
                              use24hFormat: true,
                              onDateTimeChanged: (value) => _selected = value,
                            ),
                          ),
                        )
                      : CalendarDatePicker(
                          initialDate: widget.initial,
                          firstDate: DateTime(widget.initial.year - 1),
                          lastDate: DateTime(DateTime.now().year + 20),
                          onDateChanged: (value) => _selected = value,
                        ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
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
                          text: '确定',
                          onPressed: () => Navigator.pop(context, _selected),
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
