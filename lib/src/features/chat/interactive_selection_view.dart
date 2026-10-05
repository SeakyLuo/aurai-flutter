import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/interactive_selection.dart';
import 'interactive_message_button.dart';
import '../../agent/ask_user_tool.dart';
import 'user_question_option_tile.dart';
import 'question_options_sheet.dart';

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
  });
  final Map<String, Object?> button;
  final Map? self;
  final bool locked, submitted, allowChange, busy;
  final bool showSubmit;
  final bool question;
  final ValueChanged<Object> onSubmit;

  @override
  State<InteractiveSelectionView> createState() =>
      _InteractiveSelectionViewState();
}

class _InteractiveSelectionViewState extends State<InteractiveSelectionView> {
  Completer<void>? _pickerClosed;
  late Set<String> _selected = _saved;
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
      _closePicker();
    }
    if (!oldWidget.locked && widget.locked || !oldWidget.busy && widget.busy)
      _closePicker();
  }

  bool get _locked =>
      widget.locked ||
      widget.button['disabled'] == true ||
      widget.busy ||
      widget.submitted && !widget.allowChange;

  void _closePicker() {
    _pickerClosed?.complete();
    _pickerClosed = null;
  }

  @override
  void dispose() {
    _closePicker();
    super.dispose();
  }

  Future<void> _chooseOptions() async {
    if (_pickerClosed != null) return;
    final config = selection;
    final closed = Completer<void>();
    _pickerClosed = closed;
    final result = await showQuestionOptionsSheet(
      context,
      options: [
        for (final option in config.options)
          UserQuestionOption(content: option['label'] as String),
      ],
      selected: {
        for (final (i, option) in config.options.indexed)
          if (_selected.contains(option['id'])) i,
      },
      multiple: config.multiple,
      readOnly: _locked,
      minimum: config.minimum,
      maximum: config.maximum,
      closeWhen: closed.future,
    );
    if (!identical(_pickerClosed, closed)) return;
    _closePicker();
    if (!mounted || result == null || _locked) return;
    setState(
      () => _selected = {
        for (final i in result) config.options[i]['id'] as String,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = selection;
    final colors = Theme.of(context).colorScheme;
    final locked = _locked;
    final valid =
        _selected.length >= config.minimum &&
        _selected.length <= config.maximum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (config.multiple && widget.showSubmit)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              config.minimum == config.maximum
                  ? '请选择 ${config.minimum} 项'
                  : '请选择 ${config.minimum}–${config.maximum} 项',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        if (widget.question &&
            config.options.length > 5 &&
            widget.submitted &&
            widget.self != null) ...[
          Text(
            '已回答',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            widget.self!['label'] as String,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.question && config.options.length > 5)
          QuestionOptionsField(
            label: widget.submitted || locked
                ? '查看选项（${config.options.length} 项）'
                : _selected.isEmpty
                ? '请选择（共 ${config.options.length} 项）'
                : [
                    for (final option in config.options)
                      if (_selected.contains(option['id']))
                        option['label'] as String,
                  ].join('、'),
            onTap: widget.busy ? null : _chooseOptions,
          )
        else
          for (final (index, option) in config.options.indexed)
            Builder(
              builder: (context) {
                final id = option['id'] as String;
                final selected = _selected.contains(id);
                final enabled =
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
                if (widget.question)
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: UserQuestionOptionTile(
                      option: UserQuestionOption(
                        content: option['label'] as String,
                      ),
                      number: index + 1,
                      multiple: config.multiple,
                      selected: selected,
                      onTap: enabled ? toggle : null,
                    ),
                  );
                return Semantics(
                  checked: selected,
                  inMutuallyExclusiveGroup: !config.multiple,
                  enabled: enabled,
                  label: option['label'] as String,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? toggle : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: CustomPaint(
                              size: const Size.square(22),
                              painter: _ChoicePainter(
                                multiple: config.multiple,
                                selected: selected,
                                color: selected
                                    ? Color.lerp(
                                        colors.primary,
                                        colors.onSurface,
                                        .35,
                                      )!
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option['label'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: selected
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                height: 1.5,
                                color: enabled || selected
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        if (widget.showSubmit) ...[
          const SizedBox(height: 8),
          InteractiveMessageButton(
            button: {
              ...widget.button,
              if (!valid && !widget.submitted) 'label': '请选择后提交',
              if (widget.submitted && !widget.allowChange)
                'label':
                    widget.button['completedLabel'] ?? widget.button['label'],
            },
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
          ),
        ],
      ],
    );
  }
}

class _ChoicePainter extends CustomPainter {
  const _ChoicePainter({
    required this.multiple,
    required this.selected,
    required this.color,
  });
  final bool multiple, selected;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (multiple) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, 2, 18, 18),
          const Radius.circular(4),
        ),
        pen,
      );
      if (selected)
        canvas.drawPath(
          Path()
            ..moveTo(6, 11)
            ..lineTo(9.5, 14.5)
            ..lineTo(16, 7.5),
          pen,
        );
    } else {
      canvas.drawCircle(const Offset(11, 11), 9, pen);
      if (selected)
        canvas.drawCircle(const Offset(11, 11), 5.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ChoicePainter old) =>
      old.multiple != multiple ||
      old.selected != selected ||
      old.color != color;
}
