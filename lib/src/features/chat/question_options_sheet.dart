import 'app_sheet_surface.dart';
import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'glass_surface.dart';
import 'thinking_indicator.dart';
import 'user_question_option_tile.dart';
import 'vote_message_heading.dart';
import 'vote_selection_hint.dart';
import 'vote_appearance.dart';

Future<Set<int>?> showQuestionOptionsSheet(
  BuildContext context, {
  required List<UserQuestionOption> options,
  required Set<int> selected,
  Future<void>? closeWhen,
  bool multiple = false,
  bool readOnly = false,
  bool vote = false,
  int minimum = 1,
  int maximum = 1,
  Widget? actions,
  String? title,
  String? body,
  QuestionIconType? headerIcon,
}) async {
  final navigator = Navigator.of(context);
  final route = ModalBottomSheetRoute<Set<int>>(
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    builder: (_) => AppSheetSurface(
      child: _QuestionOptionsSheet(
        options: options,
        selected: selected,
        multiple: multiple,
        readOnly: readOnly,
        vote: vote,
        minimum: minimum,
        maximum: maximum,
        actions: actions,
        title: title,
        body: body,
        headerIcon: headerIcon,
      ),
    ),
  );
  closeWhen?.then((_) {
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
    this.arrow = SettingsIconType.chevronDown,
  });
  final String label;
  final VoidCallback? onTap;
  final bool compact;
  final SettingsIconType arrow;

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
                      child: SettingsIcon(type: arrow, color: color),
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
    required this.vote,
    required this.minimum,
    required this.maximum,
    this.actions,
    this.title,
    this.body,
    this.headerIcon,
  });
  final List<UserQuestionOption> options;
  final Set<int> selected;
  final bool multiple;
  final bool readOnly;
  final bool vote;
  final int minimum, maximum;
  final Widget? actions;
  final String? title, body;
  final QuestionIconType? headerIcon;

  @override
  State<_QuestionOptionsSheet> createState() => _QuestionOptionsSheetState();
}

class _QuestionOptionsSheetState extends State<_QuestionOptionsSheet> {
  late final _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) => widget.vote
      ? _buildVote(context)
      : AppSheetSurface(
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.headerIcon != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ThinkingIndicator(
                              label: widget.title!,
                              animate: false,
                              singleLine: true,
                              leading: SizedBox.square(
                                dimension: MediaQuery.textScalerOf(
                                  context,
                                ).scale(18),
                                child: FittedBox(
                                  child: QuestionIcon(type: widget.headerIcon!),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SettingsGlassActionSurface(
                            child: IntrinsicHeight(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RoundAction(
                                    label: '关闭',
                                    icon: Icons.close_rounded,
                                    iconWidget: const QuestionIcon(
                                      type: QuestionIconType.close,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  if (widget.multiple && !widget.readOnly) ...[
                                    const VerticalDivider(
                                      width: 1,
                                      indent: 12,
                                      endIndent: 12,
                                    ),
                                    RoundAction(
                                      label: '确认',
                                      icon: Icons.check_rounded,
                                      iconWidget: const SettingsIcon(
                                        type: SettingsIconType.check,
                                      ),
                                      onPressed:
                                          _selected.length >= widget.minimum &&
                                              _selected.length <= widget.maximum
                                          ? () => Navigator.pop(
                                              context,
                                              _selected,
                                            )
                                          : null,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
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
                              widget.title ??
                                  (widget.readOnly
                                      ? '查看选项'
                                      : widget.multiple
                                      ? '选择选项（已选 ${_selected.length} 项）'
                                      : '选择选项'),
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
                      itemCount:
                          widget.options.length +
                          (widget.body?.isNotEmpty == true ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final hasBody = widget.body?.isNotEmpty == true;
                        if (hasBody && index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              widget.body!,
                              style: TextStyle(
                                fontSize: widget.headerIcon == null ? 15 : 17,
                                height: 1.5,
                                fontWeight: widget.headerIcon == null
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        final optionIndex = index - (hasBody ? 1 : 0);
                        final selected = _selected.contains(optionIndex);
                        return UserQuestionOptionTile(
                          option: widget.options[optionIndex],
                          number: optionIndex + 1,
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
                                    Navigator.pop(context, {optionIndex});
                                  } else {
                                    setState(() {
                                      if (selected) {
                                        _selected.remove(optionIndex);
                                      } else {
                                        _selected.add(optionIndex);
                                      }
                                    });
                                  }
                                },
                        );
                      },
                    ),
                  ),
                  if (widget.actions case final actions?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: actions,
                    ),
                ],
              ),
            ),
          ),
        );

  Widget _buildVote(BuildContext context) {
    final hint = voteSelectionHint(widget.minimum, widget.maximum);
    final hasBody =
        widget.body?.isNotEmpty == true &&
        widget.body != hint &&
        widget.body != '$hint。';
    final valid =
        _selected.length >= widget.minimum &&
        _selected.length <= widget.maximum;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: VoteMessageHeading(
                title: widget.title!,
                multiple: widget.multiple,
                ongoing: !widget.readOnly,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  if (hasBody) ...[
                    Text(
                      widget.body!,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ...[
                    VoteSelectionHint(
                      minimum: widget.minimum,
                      maximum: widget.maximum,
                      selectedCount: _selected.length,
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final (index, option) in widget.options.indexed)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == widget.options.length - 1 ? 0 : 8,
                      ),
                      child: UserQuestionOptionTile(
                        option: option,
                        number: index + 1,
                        selected: _selected.contains(index),
                        multiple: widget.multiple,
                        vote: true,
                        onTap:
                            widget.readOnly ||
                                widget.multiple &&
                                    !_selected.contains(index) &&
                                    _selected.length >= widget.maximum
                            ? null
                            : () {
                                if (!widget.multiple) {
                                  setState(() {
                                    _selected
                                      ..clear()
                                      ..add(index);
                                  });
                                } else {
                                  setState(() {
                                    if (!_selected.remove(index))
                                      _selected.add(index);
                                  });
                                }
                              },
                      ),
                    ),
                ],
              ),
            ),
            if (!widget.readOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: VoteSubmitButton(
                  busy: false,
                  locked: !valid,
                  onPressed: () => Navigator.pop(context, _selected),
                ),
              ),
            if (widget.actions case final actions?)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: actions,
              ),
          ],
        ),
      ),
    );
  }
}
