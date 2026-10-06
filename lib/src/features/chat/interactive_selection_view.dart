import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/interactive_selection.dart';
import 'interactive_message_button.dart';
import '../../agent/ask_user_tool.dart';
import 'user_question_option_tile.dart';
import 'question_options_sheet.dart';
import 'settings_icon.dart';
import 'vote_selection_hint.dart';
import 'vote_appearance.dart';

class InteractiveSelectionView extends StatefulWidget {
  const InteractiveSelectionView({
    super.key,
    required this.button,
    required this.self,
    required this.locked,
    required this.submitted,
    required this.allowChange,
    required this.busy,
    required this.onSubmit,
    this.showSubmit = true,
    this.question = false,
    required this.compactOptions,
    required this.title,
    required this.body,
    this.sheetActions,
    this.summary,
    this.draftSelection,
    this.onSelectionChanged,
  });
  final Map<String, Object?> button;
  final Map? self;
  final bool locked, submitted, allowChange, busy;
  final bool showSubmit;
  final bool question;
  final bool compactOptions;
  final String title, body;
  final Widget? sheetActions;
  final String? summary;
  final Set<String>? draftSelection;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final ValueChanged<Object> onSubmit;

  @override
  State<InteractiveSelectionView> createState() =>
      _InteractiveSelectionViewState();
}

class _InteractiveSelectionViewState extends State<InteractiveSelectionView>
    with AutomaticKeepAliveClientMixin {
  Completer<void>? _pickerClosed;
  late Set<String> _selected = widget.draftSelection ?? _saved;
  @override
  bool get wantKeepAlive => widget.busy || _pickerClosed != null;
  InteractiveSelection get selection => InteractiveSelection(
    Map<String, Object?>.from(widget.button['selection'] as Map),
  );
  Set<String> get _saved => {
    if (widget.self?['buttonId'] == widget.button['id'])
      for (final option in widget.self?['selections'] as List? ?? const [])
        option['optionId'] as String,
  };

  @override
  void didUpdateWidget(InteractiveSelectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.button['selection']) !=
            jsonEncode(widget.button['selection']) ||
        jsonEncode(oldWidget.self) != jsonEncode(widget.self)) {
      _selected = _saved;
    }
    if (_pickerClosed != null &&
        (jsonEncode(oldWidget.button['selection']) !=
                jsonEncode(widget.button['selection']) ||
            oldWidget.locked != widget.locked ||
            oldWidget.submitted != widget.submitted)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _closePicker();
      });
    }
    updateKeepAlive();
  }

  bool get _locked =>
      widget.locked ||
      widget.button['disabled'] == true ||
      widget.busy ||
      widget.submitted && !widget.allowChange;

  void _closePicker() {
    _pickerClosed?.complete();
    _pickerClosed = null;
    updateKeepAlive();
  }

  @override
  void dispose() {
    _pickerClosed?.complete();
    _pickerClosed = null;
    super.dispose();
  }

  Future<void> _chooseOptions() async {
    if (_pickerClosed != null) return;
    final closed = Completer<void>();
    _pickerClosed = closed;
    updateKeepAlive();
    final config = selection;
    final selected = await showQuestionOptionsSheet(
      context,
      options: [
        for (final option in config.options)
          UserQuestionOption(content: option['label'] as String),
      ],
      selected: {
        for (final (index, option) in config.options.indexed)
          if (_selected.contains(option['id'])) index,
      },
      multiple: config.multiple,
      onSelectionChanged: (selected) {
        setState(() {
          _selected = {
            for (final index in selected) config.options[index]['id'] as String,
          };
        });
        widget.onSelectionChanged?.call(Set.of(_selected));
      },
      vote: !widget.question,
      minimum: config.minimum,
      maximum: config.maximum,
      readOnly:
          widget.question && widget.submitted || _locked || !widget.showSubmit,
      closeWhen: closed.future,
      actions: widget.sheetActions,
      title: widget.title,
      body: widget.body,
    );
    if (!mounted || selected == null || _locked || !widget.showSubmit) {
      if (identical(_pickerClosed, closed)) _closePicker();
      return;
    }
    setState(() {
      _selected = {
        for (final index in selected) config.options[index]['id'] as String,
      };
    });
    widget.onSelectionChanged?.call(Set.of(_selected));
    updateKeepAlive();
    widget.onSubmit(
      config.multiple
          ? [
              for (final option in config.options)
                if (_selected.contains(option['id'])) option['id'],
            ]
          : _selected.single,
    );
    if (identical(_pickerClosed, closed)) _closePicker();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    final config = selection;
    final colors = Theme.of(context).colorScheme;
    final locked = _locked;
    final answeredQuestion = widget.question && widget.submitted;
    final truncated =
        !answeredQuestion && widget.compactOptions && config.options.length > 5;
    final valid =
        _selected.length >= config.minimum &&
        _selected.length <= config.maximum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!answeredQuestion &&
            widget.showSubmit &&
            (config.multiple || widget.summary?.isNotEmpty == true))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: !widget.question
                ? VoteSelectionHint(
                    minimum: config.minimum,
                    maximum: config.maximum,
                    selectedCount: _selected.length,
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            if (config.multiple)
                              config.minimum == config.maximum
                                  ? '请选择 ${config.minimum} 项'
                                  : !widget.question && config.minimum == 1
                                  ? '最多选 ${config.maximum} 项'
                                  : '请选择 ${config.minimum}–${config.maximum} 项',
                            if (widget.summary?.isNotEmpty == true)
                              widget.summary!,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        for (final (index, option)
            in config.options
                .take(truncated ? 4 : config.options.length)
                .indexed
                .where(
                  (entry) =>
                      !answeredQuestion || _selected.contains(entry.$2['id']),
                ))
          Builder(
            builder: (context) {
              final id = option['id'] as String;
              final selected = _selected.contains(id);
              final enabled =
                  widget.showSubmit &&
                  !locked &&
                  (!config.multiple ||
                      selected ||
                      _selected.length < config.maximum);
              void toggle() => setState(() {
                if (!config.multiple) {
                  _selected = {id};
                } else if (selected) {
                  _selected.remove(id);
                } else {
                  _selected.add(id);
                }
              });
              void choose() {
                toggle();
                widget.onSelectionChanged?.call(Set.of(_selected));
                updateKeepAlive();
                if (widget.question && !config.multiple) widget.onSubmit(id);
              }

              return Padding(
                padding: EdgeInsets.only(bottom: answeredQuestion ? 0 : 8),
                child: UserQuestionOptionTile(
                  option: UserQuestionOption(
                    content: option['label'] as String,
                  ),
                  number: index + 1,
                  multiple: config.multiple,
                  vote: !widget.question,
                  selected: selected,
                  onTap: answeredQuestion
                      ? null
                      : enabled
                      ? choose
                      : null,
                ),
              );
            },
          ),
        if (truncated)
          QuestionOptionsField(
            label: '查看全部选项',
            compact: true,
            arrow: SettingsIconType.chevron,
            onTap: _chooseOptions,
          ),
        if (truncated &&
            config.options
                .skip(4)
                .any((option) => _selected.contains(option['id'])))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '已选：${config.options.where((option) => _selected.contains(option['id'])).map((option) => option['label']).join('、')}',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        if (!answeredQuestion &&
            widget.showSubmit &&
            (!widget.question || config.multiple)) ...[
          const SizedBox(height: 8),
          if (!widget.question)
            VoteSubmitButton(
              busy: widget.busy,
              locked: locked || !valid,
              onPressed: () => widget.onSubmit(
                config.multiple
                    ? [
                        for (final option in config.options)
                          if (_selected.contains(option['id'])) option['id'],
                      ]
                    : _selected.single,
              ),
            )
          else
            InteractiveMessageButton(
              button: {
                ...widget.button,
                if (widget.submitted && !widget.allowChange)
                  'label':
                      widget.button['completedLabel'] ?? widget.button['label'],
              },
              busy: widget.busy,
              locked: locked || !valid,
              onPressed: () => widget.onSubmit([
                for (final option in config.options)
                  if (_selected.contains(option['id'])) option['id'],
              ]),
            ),
        ],
      ],
    );
  }
}
