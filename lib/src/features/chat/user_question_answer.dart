import 'dart:async';
import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import 'glass_surface.dart';
import 'message_composer.dart';
import 'user_question_option_tile.dart';
import 'question_options_sheet.dart';

class UserQuestionAnswer extends StatefulWidget {
  const UserQuestionAnswer({super.key, required this.question});
  final UserQuestion question;

  @override
  State<UserQuestionAnswer> createState() => _UserQuestionAnswerState();
}

class _UserQuestionAnswerState extends State<UserQuestionAnswer> {
  late final _text = TextEditingController(text: widget.question.draft);
  final _focus = FocusNode();
  Completer<void>? _pickerClosed;

  Future<void> _chooseOption() async {
    if (_pickerClosed != null) return;
    _focus.unfocus();
    final question = widget.question;
    final closed = Completer<void>();
    _pickerClosed = closed;
    final selected = await showQuestionOptionsSheet(
      context,
      options: [
        for (var i = 0; i < question.options.length; i++) question.optionAt(i),
      ],
      selected: {if (question.selected != null) question.selected!},
      closeWhen: Future.any([
        question.result.future.then((_) {}),
        closed.future,
      ]),
    );
    if (!identical(_pickerClosed, closed)) return;
    _pickerClosed = null;
    closed.complete();
    if (!mounted || selected == null || question.result.isCompleted) return;
    question.selected = selected.single;
    question.draft = '';
    _text.clear();
    _submit();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.question.answer();
  }

  @override
  void dispose() {
    _pickerClosed?.complete();
    _pickerClosed = null;
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final enabled = !question.result.isCompleted;
    final canSend =
        enabled && (_text.text.trim().isNotEmpty || question.selected != null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Text(
            question.question,
            style: const TextStyle(
              fontSize: 17,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (question.options.length > 5)
          QuestionOptionsField(
            label: '选择回答（${question.options.length} 项）',
            onTap: enabled ? _chooseOption : null,
          )
        else
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == question.options.length - 1 ? 0 : 8,
              ),
              child: UserQuestionOptionTile(
                option: question.optionAt(i),
                number: i + 1,
                selected: question.selected == i,
                onTap: !enabled
                    ? null
                    : () {
                        question.selected = i;
                        question.draft = '';
                        _text.clear();
                        _submit();
                      },
              ),
            ),
        if (question.allowCustomAnswer) ...[
          const SizedBox(height: 8),
          MessageComposer(
            embedded: true,
            controller: _text,
            focusNode: _focus,
            enabled: enabled,
            hintText: question.customAnswerPlaceholder ?? '或自行撰写回复',
            onChanged: (value) => setState(() {
              question.draft = value;
              question.selected = null;
            }),
            action: RoundAction(
              label: '发送回答',
              inkResponse: false,
              primary: true,
              compact: true,
              icon: Icons.arrow_upward_rounded,
              onPressed: canSend ? _submit : null,
            ),
          ),
        ],
      ],
    );
  }
}
