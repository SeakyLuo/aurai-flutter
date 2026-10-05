import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import '../../app/global_ui.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'user_question_option_tile.dart';

Future<Set<int>?> showQuestionOptionsSheet(
  BuildContext context, {
  required List<UserQuestionOption> options,
  required Set<int> selected,
  required Future<void> closeWhen,
  bool multiple = false,
  int minimum = 1,
  int maximum = 1,
}) async {
  final navigator = Navigator.of(context);
  final route = ModalBottomSheetRoute<Set<int>>(
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    builder: (_) => _QuestionOptionsSheet(
      options: options,
      selected: selected,
      multiple: multiple,
      minimum: minimum,
      maximum: maximum,
    ),
  );
  closeWhen.then((_) {
    if (!route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  });
  final result = await navigator.push(route);
  // Finish transferring focus before the parent question submits or closes.
  await route.completed;
  return result;
}

class QuestionOptionsField extends StatelessWidget {
  const QuestionOptionsField({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: settingsFieldColor(context),
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const SettingsIcon(type: SettingsIconType.chevronDown),
      onTap: onTap,
    ),
  );
}

class _QuestionOptionsSheet extends StatefulWidget {
  const _QuestionOptionsSheet({
    required this.options,
    required this.selected,
    required this.multiple,
    required this.minimum,
    required this.maximum,
  });
  final List<UserQuestionOption> options;
  final Set<int> selected;
  final bool multiple;
  final int minimum, maximum;

  @override
  State<_QuestionOptionsSheet> createState() => _QuestionOptionsSheetState();
}

class _QuestionOptionsSheetState extends State<_QuestionOptionsSheet> {
  late final _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: GlobalUI.bottomSheetBorderRadius,
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  SettingsGlassAction(
                    label: '关闭',
                    icon: Icons.close_rounded,
                    iconWidget: const QuestionIcon(
                      type: QuestionIconType.close,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.multiple
                          ? '选择选项（已选 ${_selected.length} 项）'
                          : '选择选项',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.multiple)
                    SettingsGlassAction(
                      label: '确认',
                      icon: Icons.check_rounded,
                      iconWidget: const SettingsIcon(
                        type: SettingsIconType.check,
                      ),
                      onPressed:
                          _selected.length >= widget.minimum &&
                              _selected.length <= widget.maximum
                          ? () => Navigator.pop(context, _selected)
                          : null,
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),
            if (widget.multiple)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.minimum == widget.maximum
                      ? '请选择 ${widget.minimum} 项'
                      : '请选择 ${widget.minimum}–${widget.maximum} 项',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: widget.options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final selected = _selected.contains(index);
                  return UserQuestionOptionTile(
                    option: widget.options[index],
                    number: index + 1,
                    selected: selected,
                    multiple: widget.multiple,
                    onTap:
                        widget.multiple &&
                            !selected &&
                            _selected.length >= widget.maximum
                        ? null
                        : () {
                            if (!widget.multiple) {
                              Navigator.pop(context, {index});
                            } else {
                              setState(() {
                                if (selected) {
                                  _selected.remove(index);
                                } else {
                                  _selected.add(index);
                                }
                              });
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
