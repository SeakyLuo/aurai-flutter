import 'dart:async';
import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import 'glass_surface.dart';
import 'message_composer.dart';
import 'question_sheet.dart';
import 'question_batch_form.dart';
import 'question_submission.dart';
import 'vote_other_input.dart';

class UserQuestionAnswer extends StatefulWidget {
  const UserQuestionAnswer({
    super.key,
    required this.question,
    this.compact = true,
  });
  final UserQuestion question;
  final bool compact;

  @override
  State<UserQuestionAnswer> createState() => _UserQuestionAnswerState();
}

class _UserQuestionAnswerState extends State<UserQuestionAnswer> {
  late final _text = TextEditingController(text: widget.question.draft);
  final _focus = FocusNode();
  Completer<void>? _pickerClosed;
  QuestionBatchController? _batch;

  @override
  void initState() {
    super.initState();
    if (widget.question.batch case final batch?) {
      _batch = QuestionBatchController(
        batch,
        answers: widget.question.answers,
        index: widget.question.questionIndex,
      )..addListener(_saveBatch);
    }
  }

  void _saveBatch() {
    widget.question.answers
      ..clear()
      ..addAll(_batch!.answers);
    widget.question.questionIndex = _batch!.index;
    saveQuestionDraft(context, widget.question);
  }

  Future<void> _chooseOption() async {
    if (_pickerClosed != null) return;
    _focus.unfocus();
    final question = widget.question;
    final closed = Completer<void>();
    _pickerClosed = closed;
    await showQuestionSheet(
      context,
      child: QuestionSheetLayout(
        title: question.title ?? '问题',
        child: UserQuestionAnswer(question: question, compact: false),
      ),
      closeWhen: Future.any([
        question.result.future.then((_) {}),
        closed.future,
      ]),
    );
    if (!identical(_pickerClosed, closed)) return;
    _pickerClosed = null;
    closed.complete();
  }

  Future<void> _customAnswer() async {
    final question = widget.question;
    final text = await showVoteOtherInput(
      context,
      title: question.question,
      initialText: question.draft,
      maxLength: 2000,
      heading: '自行撰写回复',
      hint: question.customAnswerPlaceholder ?? '填写你的回答',
      closeWhen: question.result.future.then((_) {}),
    );
    if (!mounted || text == null || question.result.isCompleted) return;
    question.draft = text;
    question.selected = null;
    _submit();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.question.answer();
  }

  @override
  void dispose() {
    _batch?.dispose();
    _pickerClosed?.complete();
    _pickerClosed = null;
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    if (_batch case final batch?) {
      return QuestionBatchForm(
        controller: batch,
        compact: widget.compact,
        readOnly: question.result.isCompleted,
        closeWhen: question.result.future.then((_) {}),
        onSubmit: () async {
          if (!question.result.isCompleted) {
            await submitQuestionAnswers(
              context,
              question,
              Map.of(batch.answers),
            );
          }
        },
      );
    }
    final enabled = !question.result.isCompleted;
    final canSend =
        enabled && (_text.text.trim().isNotEmpty || question.selected != null);
    return QuestionAnswerContent(
      question: question.question,
      options: [
        for (var i = 0; i < question.options.length; i++) question.optionAt(i),
      ],
      selected: {if (question.selected != null) question.selected!},
      compactOptions: widget.compact,
      allowCustomAnswer: question.allowCustomAnswer,
      customAnswer: question.draft,
      onCustomAnswer: enabled ? _customAnswer : null,
      onChooseOptions: enabled ? _chooseOption : null,
      onSelect: !enabled
          ? null
          : (index) {
              question.selected = index;
              question.draft = '';
              _text.clear();
              _submit();
            },
      footer: question.allowCustomAnswer && question.options.isEmpty
          ? Column(
              children: [
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
            )
          : null,
    );
  }
}
