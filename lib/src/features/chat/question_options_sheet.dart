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
  bool readOnly = false,
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
      readOnly: readOnly,
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
  const QuestionOptionsField({
    super.key,
    required this.label,
    this.onTap,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      final color = Theme.of(context).colorScheme.onSurfaceVariant;
      return Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 14, height: 1.4, color: color),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox.square(
                    dimension: 20,
                    child: FittedBox(
                      child: SettingsIcon(
                        type: SettingsIconType.chevronDown,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
              const SizedBox(width: 12),
              const SettingsIcon(type: SettingsIconType.chevronDown),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionOptionsSheet extends StatefulWidget {
  const _QuestionOptionsSheet({
    required this.options,
    required this.selected,
    required this.multiple,
    required this.readOnly,
    required this.minimum,
    required this.maximum,
  });
  final List<UserQuestionOption> options;
  final Set<int> selected;
  final bool multiple;
  final bool readOnly;
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
                      widget.readOnly
                          ? '查看选项'
                          : widget.multiple
                          ? '选择选项（已选 ${_selected.length} 项）'
                          : '选择选项',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.multiple && !widget.readOnly)
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
            if (widget.multiple && !widget.readOnly)
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
                        widget.readOnly ||
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
