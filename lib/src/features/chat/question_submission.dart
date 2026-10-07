import 'package:flutter/material.dart';
import '../../agent/ask_user_tool.dart';
import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'dart:convert';
import '../../storage/interactive_selection_drafts.dart';

Future<void> submitQuestionAnswers(
  BuildContext context,
  UserQuestion question,
  Map<String, Object?> answers,
) async {
  try {
    FocusScope.of(context).unfocus();
    await question.submitBatch(answers);
  } on Object catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showToast(
        SnackBar(content: Text(errorMessage(error))),
        kind: ToastKind.error,
      );
  }
}

Future<void> saveQuestionDraft(
  BuildContext context,
  UserQuestion question,
) async {
  if (question.messageId == null) return;
  try {
    await InteractiveSelectionDrafts.instance.save(
      question.messageId!,
      'user:local',
      'answer',
      jsonEncode([0, question.batch!.questions]),
      {},
      otherText: jsonEncode({
        'index': question.questionIndex,
        'answers': question.answers,
      }),
    );
  } on Object catch (error) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showToast(
        SnackBar(content: Text(errorMessage(error))),
        kind: ToastKind.error,
      );
  }
}
