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
import 'vote_other_input.dart';
import 'vote_other_option_tile.dart';
import 'interactive_message_button.dart';
import 'rich_option_carousel.dart';

Future<Set<int>?> showQuestionOptionsSheet(
  BuildContext context, {
  required List<UserQuestionOption> options,
  required Set<int> selected,
  ValueChanged<Set<int>>? onSelectionChanged,
  Future<void>? closeWhen,
  bool multiple = false,
  bool showConfirm = false,
  bool readOnly = false,
  bool showSelectionIndicator = true,
  bool vote = false,
  String? optionPrefix,
  bool anonymous = false,
  String? voteStatus,
  int minimum = 1,
  int maximum = 1,
  Widget? actions,
  String? title,
  String? body,
  Widget? heading,
  QuestionIconType? headerIcon,
  int? otherIndex,
  String otherText = '',
  int otherMaxLength = 50,
  ValueChanged<String>? onOtherTextChanged,
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
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: QuestionOptionsSheet(
        options: options,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        multiple: multiple,
        showConfirm: showConfirm,
        readOnly: readOnly,
        showSelectionIndicator: showSelectionIndicator,
        vote: vote,
        optionPrefix: optionPrefix,
        anonymous: anonymous,
        voteStatus: voteStatus,
        minimum: minimum,
        maximum: maximum,
        actions: actions,
        title: title,
        body: body,
        heading: heading,
        headerIcon: headerIcon,
        otherIndex: otherIndex,
        otherText: otherText,
        otherMaxLength: otherMaxLength,
        onOtherTextChanged: onOtherTextChanged,
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
    this.arrow = SettingsIconType.chevron,
    this.maxLines,
  });
  final String label;
  final VoidCallback? onTap;
  final bool compact;
  final SettingsIconType arrow;
  final int? maxLines;

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
                      maxLines: maxLines,
                      overflow: maxLines == null ? null : TextOverflow.ellipsis,
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
                  maxLines: maxLines,
                  overflow: maxLines == null ? null : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
              const SizedBox(width: 12),
              SettingsIcon(type: arrow),
            ],
          ),
        ),
      ),
    );
  }
}

class QuestionOptionsSheet extends StatefulWidget {
  const QuestionOptionsSheet({
    super.key,
    required this.options,
    required this.selected,
    this.onSelectionChanged,
    required this.multiple,
    required this.readOnly,
    required this.vote,
    this.showConfirm = false,
    this.showSelectionIndicator = true,
    this.optionPrefix,
    required this.anonymous,
    this.voteStatus,
    required this.minimum,
    required this.maximum,
    this.actions,
    this.title,
    this.body,
    this.heading,
    this.headerIcon,
    this.otherIndex,
    this.otherText = '',
    this.otherMaxLength = 50,
    this.onOtherTextChanged,
    this.onSubmit,
    this.busy = false,
  });
  final List<UserQuestionOption> options;
  final Set<int> selected;
  final ValueChanged<Set<int>>? onSelectionChanged;
  final bool multiple;
  final bool readOnly;
  final bool showSelectionIndicator;
  final bool vote;
  final String? optionPrefix;
  final bool showConfirm;
  final bool anonymous;
  final String? voteStatus;
  final int minimum, maximum;
  final Widget? actions;
  final String? title, body;
  final Widget? heading;
  final QuestionIconType? headerIcon;
  final int? otherIndex;
  final String otherText;
  final int otherMaxLength;
  final ValueChanged<String>? onOtherTextChanged;
  final ValueChanged<Set<int>>? onSubmit;
  final bool busy;

  @override
  State<QuestionOptionsSheet> createState() => _QuestionOptionsSheetState();
}

class _QuestionOptionsSheetState extends State<QuestionOptionsSheet> {
  late final _selected = {...widget.selected};
  late String _otherText = widget.otherText;
  bool _editingOther = false;

  @override
  void didUpdateWidget(QuestionOptionsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected.length != oldWidget.selected.length ||
        !widget.selected.containsAll(oldWidget.selected)) {
      _selected
        ..clear()
        ..addAll(widget.selected);
    }
    if (widget.otherText != oldWidget.otherText) _otherText = widget.otherText;
  }

  void _submit(Set<int> selected) {
    if (widget.onSubmit != null) {
      widget.onSubmit!(Set.of(selected));
    } else {
      Navigator.pop(context, selected);
    }
  }

  bool get _rich => widget.options.any((option) => option.messageId != null);
  bool get _confirm => widget.multiple || widget.showConfirm || _rich;

  Widget _carousel() => RichOptionCarousel(
    options: widget.options,
    selected: _selected,
    multiple: widget.multiple,
    maximum: widget.maximum,
    optionPrefix: widget.optionPrefix,
    showSelectionIndicator: widget.showSelectionIndicator,
    onSelect: widget.readOnly || widget.busy
        ? null
        : (index) {
            if (index == widget.otherIndex && !_selected.contains(index)) {
              setState(() => _editingOther = true);
              return;
            }
            setState(() {
              if (!widget.multiple) _selected.clear();
              if (!_selected.remove(index)) _selected.add(index);
            });
            widget.onSelectionChanged?.call(Set.of(_selected));
          },
  );

  void _finishOther(String text) {
    FocusScope.of(context).unfocus();
    setState(() {
      _otherText = text;
      _editingOther = false;
      if (!widget.multiple) _selected.clear();
      _selected.add(widget.otherIndex!);
    });
    widget.onOtherTextChanged?.call(text);
    widget.onSelectionChanged?.call(Set.of(_selected));
    if (!_confirm) _submit(_selected);
  }

  void _cancelOther() {
    FocusScope.of(context).unfocus();
    setState(() => _editingOther = false);
  }

  @override
  Widget build(BuildContext context) => _editingOther
      ? PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _cancelOther();
          },
          child: VoteOtherInput(
            title: widget.title!,
            initialText: _otherText,
            maxLength: widget.otherMaxLength,
            onCancel: _cancelOther,
            onComplete: _finishOther,
          ),
        )
      : widget.vote
      ? AppSheetSurface(child: _buildVote(context))
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
                  if (widget.heading case final heading?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: heading,
                    )
                  else if (widget.headerIcon != null)
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
                                  if (widget.multiple &&
                                      !widget.readOnly &&
                                      widget.title == null) ...[
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
                                          ? () => _submit(_selected)
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
                          if (widget.multiple &&
                              !widget.readOnly &&
                              widget.title == null)
                            SettingsGlassAction(
                              label: '确认',
                              icon: Icons.check_rounded,
                              iconWidget: const SettingsIcon(
                                type: SettingsIconType.check,
                              ),
                              onPressed:
                                  _selected.length >= widget.minimum &&
                                      _selected.length <= widget.maximum
                                  ? () => _submit(_selected)
                                  : null,
                            )
                          else
                            const SizedBox(width: 40),
                        ],
                      ),
                    ),
                  if (widget.multiple && !widget.readOnly)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: VoteSelectionHint(
                        minimum: widget.minimum,
                        maximum: widget.maximum,
                        selectedCount: _selected.length,
                      ),
                    ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount:
                          (_rich ? 1 : widget.options.length) +
                          (widget.heading == null &&
                                  widget.body?.isNotEmpty == true
                              ? 1
                              : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final hasBody =
                            widget.heading == null &&
                            widget.body?.isNotEmpty == true;
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
                        if (_rich) return _carousel();
                        final selected = _selected.contains(optionIndex);
                        return UserQuestionOptionTile(
                          option: widget.options[optionIndex],
                          number: optionIndex + 1,
                          optionPrefix: widget.optionPrefix,
                          showSelectionIndicator: widget.showSelectionIndicator,
                          selected: selected,
                          multiple: widget.multiple,
                          onTap:
                              widget.readOnly ||
                                  widget.multiple &&
                                      !selected &&
                                      _selected.length >= widget.maximum
                              ? null
                              : () {
                                  if (!_confirm) {
                                    _submit({optionIndex});
                                  } else {
                                    setState(() {
                                      if (!widget.multiple) _selected.clear();
                                      if (selected) {
                                        _selected.remove(optionIndex);
                                      } else {
                                        _selected.add(optionIndex);
                                      }
                                    });
                                    widget.onSelectionChanged?.call(
                                      Set.of(_selected),
                                    );
                                  }
                                },
                        );
                      },
                    ),
                  ),
                  if (_confirm &&
                      !widget.readOnly &&
                      (widget.title != null || _rich))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: InteractiveMessageButton(
                        button: const {'label': '提交回答', 'style': 'primary'},
                        busy: widget.busy,
                        locked:
                            _selected.length < widget.minimum ||
                            _selected.length > widget.maximum,
                        onPressed: () => _submit(_selected),
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
        _selected.length <= widget.maximum &&
        (!_selected.contains(widget.otherIndex) || _otherText.isNotEmpty);
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
                ongoing: widget.voteStatus == '进行中',
                anonymous: widget.anonymous,
                status: widget.voteStatus,
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
                  if (widget.multiple) ...[
                    VoteSelectionHint(
                      minimum: widget.minimum,
                      maximum: widget.maximum,
                      selectedCount: _selected.length,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_rich)
                    _carousel()
                  else
                    for (final (index, option) in widget.options.indexed)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == widget.options.length - 1 ? 0 : 8,
                        ),
                        child: index == widget.otherIndex
                            ? VoteOtherOptionTile(
                                text: _otherText,
                                selected: _selected.contains(index),
                                multiple: widget.multiple,
                                number: index + 1,
                                optionPrefix: widget.optionPrefix,
                                showSelectionIndicator:
                                    widget.showSelectionIndicator,
                                onEdit:
                                    widget.readOnly ||
                                        widget.multiple &&
                                            !_selected.contains(index) &&
                                            _selected.length >= widget.maximum
                                    ? null
                                    : () =>
                                          setState(() => _editingOther = true),
                                onToggle:
                                    widget.readOnly ||
                                        widget.multiple &&
                                            !_selected.contains(index) &&
                                            _selected.length >= widget.maximum
                                    ? null
                                    : () {
                                        if (_selected.contains(index)) {
                                          setState(
                                            () => _selected.remove(index),
                                          );
                                          widget.onSelectionChanged?.call(
                                            Set.of(_selected),
                                          );
                                        } else {
                                          setState(() => _editingOther = true);
                                        }
                                      },
                              )
                            : UserQuestionOptionTile(
                                option: option,
                                number: index + 1,
                                optionPrefix: widget.optionPrefix,
                                showSelectionIndicator:
                                    widget.showSelectionIndicator,
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
                                        widget.onSelectionChanged?.call(
                                          Set.of(_selected),
                                        );
                                        if (!_confirm) _submit(_selected);
                                      },
                              ),
                      ),
                ],
              ),
            ),
            if (!widget.readOnly && _confirm)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: VoteSubmitButton(
                  busy: widget.busy,
                  locked: !valid,
                  onPressed: () => _submit(_selected),
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
