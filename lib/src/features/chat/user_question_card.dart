import 'package:flutter/material.dart';
import '../../agent/ask_user_tool.dart';
import 'question_sheet.dart';
import 'user_question_answer.dart';
import 'user_question_skip_button.dart';
import 'question_batch_form.dart';
import 'question_submission.dart';
import 'question_card_anchor.dart';

Future<void> showUserQuestionSheet(
  BuildContext context, {
  required UserQuestion question,
  required bool showSender,
  required VoidCallback onOpenSender,
}) async {
  question.sheetVisible.value = true;
  try {
    await showQuestionSheet(
      context,
      returnTarget: question.messageId == null
          ? null
          : () => QuestionCardAnchor.bounds(question.messageId!),
      child: UserQuestionCard(
        question: question,
        showSender: showSender,
        onOpenSender: onOpenSender,
      ),
    );
  } finally {
    question.sheetVisible.value = false;
  }
}

class UserQuestionCard extends StatefulWidget {
  const UserQuestionCard({
    super.key,
    required this.question,
    required this.onOpenSender,
    this.showSender = false,
  });
  final UserQuestion question;
  final bool showSender;
  final VoidCallback onOpenSender;

  @override
  State<UserQuestionCard> createState() => _UserQuestionCardState();
}

class _UserQuestionCardState extends State<UserQuestionCard> {
  QuestionBatchController? _batch;
  @override
  void initState() {
    super.initState();
    if (widget.question.batch case final batch?) {
      _batch = QuestionBatchController(
        batch,
        answers: widget.question.answers,
        index: widget.question.questionIndex,
      )..addListener(_saveDraft);
    }
    widget.question.result.future.then((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context)!;
      if (!route.isActive) return;
      final navigator = Navigator.of(context);
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
    });
  }

  void _saveDraft() {
    widget.question.answers
      ..clear()
      ..addAll(_batch!.answers);
    widget.question.questionIndex = _batch!.index;
    saveQuestionDraft(context, widget.question);
  }

  @override
  void dispose() {
    _batch?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => QuestionSheetLayout(
    title: widget.question.title ?? '问题',
    scrollBody: _batch == null,
    heading: _batch == null ? null : const SizedBox.shrink(),
    trailing: UserQuestionSkipButton(question: widget.question),
    sender: widget.showSender ? widget.question.sender : null,
    onOpenSender: widget.onOpenSender,
    child: _batch == null
        ? UserQuestionAnswer(question: widget.question)
        : QuestionBatchForm(
            controller: _batch!,
            scrollable: true,
            compact: true,
            trailing: UserQuestionSkipButton(question: widget.question),
            closeWhen: widget.question.result.future.then((_) {}),
            onSubmit: () async {
              if (!widget.question.result.isCompleted) {
                await submitQuestionAnswers(
                  context,
                  widget.question,
                  Map.of(_batch!.answers),
                );
              }
            },
          ),
  );
}
