import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/interactive_selection.dart';
import '../../domain/selection_option.dart';
import 'rich_option_carousel.dart';
import 'interactive_message_button.dart';
import '../../agent/ask_user_tool.dart';
import 'user_question_option_tile.dart';
import 'question_options_sheet.dart';
import 'settings_icon.dart';
import 'vote_selection_hint.dart';
import 'vote_appearance.dart';
import 'vote_other_input.dart';
import 'vote_other_option_tile.dart';

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
    this.questionHeading,
    this.anonymous = false,
    this.voteStatus,
    required this.compactOptions,
    required this.title,
    required this.body,
    this.sheetActions,
    this.summary,
    this.draftSelection,
    this.draftOtherText,
    this.onSelectionChanged,
    this.fullSheet = false,
  });
  final Map<String, Object?> button;
  final Map? self;
  final bool locked, submitted, allowChange, busy;
  final bool showSubmit;
  final bool question;
  final Widget? questionHeading;
  final bool anonymous;
  final String? voteStatus;
  final bool compactOptions;
  final bool fullSheet;
  final String title, body;
  final Widget? sheetActions;
  final String? summary;
  final Set<String>? draftSelection;
  final String? draftOtherText;
  final void Function(Set<String> selected, String otherText)?
  onSelectionChanged;
  final ValueChanged<Object> onSubmit;

  @override
  State<InteractiveSelectionView> createState() =>
      _InteractiveSelectionViewState();
}

class _InteractiveSelectionViewState extends State<InteractiveSelectionView>
    with AutomaticKeepAliveClientMixin {
  Completer<void>? _pickerClosed;
  late Set<String> _selected = widget.draftSelection ?? _saved;
  late String _otherText = widget.draftOtherText ?? _savedOtherText;
  String get _savedOtherText => widget.self?['buttonId'] == widget.button['id']
      ? ((widget.self?['selections'] as List? ?? const [])
                    .where(
                      (option) =>
                          option['optionId'] == InteractiveSelection.otherId,
                    )
                    .firstOrNull?['text']
                as String? ??
            '')
      : '';
  void _saveDraft() =>
      widget.onSelectionChanged?.call(Set.of(_selected), _otherText);
  Object _submission() {
    final config = selection;
    final selected = config.multiple
        ? [
            for (final option in config.options)
              if (_selected.contains(option['id'])) option['id'],
          ]
        : _selected.single;
    return config.hasOther && _selected.contains(InteractiveSelection.otherId)
        ? {'options': selected, 'otherText': _otherText}
        : selected;
  }

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
      _otherText = _savedOtherText;
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
          UserQuestionOption.fromSelection(option),
      ],
      otherIndex: config.hasOther ? config.options.length - 1 : null,
      otherText: _otherText,
      otherMaxLength: config.otherMaxLength,
      onOtherTextChanged: (text) {
        setState(() => _otherText = text);
      },
      selected: {
        for (final (index, option) in config.options.indexed)
          if (_selected.contains(option['id'])) index,
      },
      multiple: config.multiple,
      optionPrefix: config.optionPrefix,
      showConfirm: config.needsConfirmation,
      onSelectionChanged: (selected) {
        setState(() {
          _selected = {
            for (final index in selected) config.options[index]['id'] as String,
          };
        });
        _saveDraft();
      },
      vote: !widget.question,
      anonymous: widget.anonymous,
      voteStatus: widget.voteStatus,
      minimum: config.minimum,
      maximum: config.maximum,
      readOnly:
          widget.question && widget.submitted || _locked || !widget.showSubmit,
      closeWhen: closed.future,
      actions: widget.sheetActions,
      title: widget.title,
      body: widget.body,
      heading: widget.questionHeading,
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
    _saveDraft();
    updateKeepAlive();
    widget.onSubmit(_submission());
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
    if (widget.fullSheet) {
      return QuestionOptionsSheet(
        key: ValueKey(jsonEncode(widget.button['selection'])),
        options: [
          for (final option in config.options)
            UserQuestionOption.fromSelection(option),
        ],
        selected: {
          for (final (index, option) in config.options.indexed)
            if (_selected.contains(option['id'])) index,
        },
        multiple: config.multiple,
        optionPrefix: config.optionPrefix,
        showConfirm: config.needsConfirmation,
        readOnly:
            widget.question && widget.submitted ||
            _locked ||
            !widget.showSubmit,
        vote: !widget.question,
        anonymous: widget.anonymous,
        voteStatus: widget.voteStatus,
        minimum: config.minimum,
        maximum: config.maximum,
        title: widget.title,
        body: widget.body,
        heading: widget.questionHeading,
        actions: widget.sheetActions,
        busy: widget.busy,
        otherIndex: config.hasOther ? config.options.length - 1 : null,
        otherText: _otherText,
        otherMaxLength: config.otherMaxLength,
        onOtherTextChanged: (text) {
          _otherText = text;
          _saveDraft();
        },
        onSelectionChanged: (indices) {
          _selected = {
            for (final index in indices) config.options[index]['id'] as String,
          };
          _saveDraft();
        },
        onSubmit: (indices) {
          _selected = {
            for (final index in indices) config.options[index]['id'] as String,
          };
          _saveDraft();
          widget.onSubmit(_submission());
        },
      );
    }
    final locked = _locked;
    final answeredQuestion = widget.question && widget.submitted;
    final rich = hasRichOptions(config.options);
    final truncated =
        !answeredQuestion &&
        !rich &&
        widget.compactOptions &&
        config.options.length >= 5;
    final valid =
        _selected.length >= config.minimum &&
        _selected.length <= config.maximum &&
        (!_selected.contains(InteractiveSelection.otherId) ||
            !config.hasOther ||
            _otherText.isNotEmpty);
    final visibleOptions = config.options
        .take(truncated ? 4 : config.options.length)
        .indexed
        .where(
          (entry) => !answeredQuestion || _selected.contains(entry.$2['id']),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!answeredQuestion &&
            widget.showSubmit &&
            (config.multiple || widget.summary?.isNotEmpty == true))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: !widget.question || config.multiple
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
        if (rich && visibleOptions.isNotEmpty)
          RichOptionCarousel(
            numbers: [for (final (index, _) in visibleOptions) index + 1],
            options: [
              for (final (_, option) in visibleOptions)
                UserQuestionOption.fromSelection(option),
            ],
            selected: {
              for (final (i, entry) in visibleOptions.indexed)
                if (_selected.contains(entry.$2['id'])) i,
            },
            multiple: config.multiple,
            maximum: config.maximum,
            optionPrefix: config.optionPrefix,
            onSelect: answeredQuestion || locked || !widget.showSubmit
                ? null
                : (i) {
                    final id = visibleOptions[i].$2['id'] as String;
                    if (id == InteractiveSelection.otherId) {
                      if (_selected.contains(id)) {
                        setState(() => _selected.remove(id));
                        _saveDraft();
                      } else {
                        _editOther();
                      }
                      return;
                    }
                    setState(() {
                      if (!config.multiple) _selected.clear();
                      if (!_selected.remove(id)) _selected.add(id);
                    });
                    _saveDraft();
                  },
          )
        else
          for (final (index, option) in visibleOptions)
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
                  _saveDraft();
                  updateKeepAlive();
                  if (!config.needsConfirmation) widget.onSubmit(id);
                }

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: answeredQuestion && index == visibleOptions.last.$1
                        ? 0
                        : 8,
                  ),
                  child: config.hasOther && id == InteractiveSelection.otherId
                      ? VoteOtherOptionTile(
                          text: _otherText,
                          selected: selected,
                          multiple: config.multiple,
                          number: index + 1,
                          optionPrefix: config.optionPrefix,
                          fontSize: InteractiveMessageButton.defaultFontSize,
                          onEdit: enabled ? _editOther : null,
                          onToggle: enabled
                              ? selected
                                    ? () {
                                        setState(() => _selected.remove(id));
                                        _saveDraft();
                                      }
                                    : _editOther
                              : null,
                        )
                      : UserQuestionOptionTile(
                          option: UserQuestionOption(
                            content: option['label'] as String,
                          ),
                          number: index + 1,
                          optionPrefix: config.optionPrefix,
                          multiple: config.multiple,
                          vote: !widget.question,
                          fontSize: InteractiveMessageButton.defaultFontSize,
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
              '已选：${config.options.where((option) => _selected.contains(option['id'])).map((option) => config.hasOther && option['id'] == InteractiveSelection.otherId ? '其他：$_otherText' : option['label']).join('、')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        if (!answeredQuestion &&
            widget.showSubmit &&
            config.needsConfirmation) ...[
          const SizedBox(height: 8),
          if (!widget.question)
            VoteSubmitButton(
              fontSize: InteractiveMessageButton.defaultFontSize,
              busy: widget.busy,
              locked: locked || !valid,
              onPressed: () => widget.onSubmit(_submission()),
            )
          else
            InteractiveMessageButton(
              button: {
                ...widget.button,
                'label': '提交回答',
                'style': 'primary',
                if (widget.submitted && !widget.allowChange)
                  'label':
                      widget.button['completedLabel'] ?? widget.button['label'],
              },
              busy: widget.busy,
              locked: locked || !valid,
              onPressed: () => widget.onSubmit(_submission()),
            ),
        ],
      ],
    );
  }

  Future<void> _editOther() async {
    if (_pickerClosed != null) return;
    final config = selection;
    final closed = Completer<void>();
    _pickerClosed = closed;
    updateKeepAlive();
    final text = await showVoteOtherInput(
      context,
      title: widget.title,
      initialText: _otherText,
      maxLength: config.otherMaxLength,
      closeWhen: closed.future,
    );
    if (identical(_pickerClosed, closed)) _closePicker();
    if (!mounted || text == null || _locked) return;
    setState(() {
      _otherText = text;
      if (!config.multiple) _selected.clear();
      _selected.add(InteractiveSelection.otherId);
    });
    _saveDraft();
    if (!config.needsConfirmation) widget.onSubmit(_submission());
  }
}
