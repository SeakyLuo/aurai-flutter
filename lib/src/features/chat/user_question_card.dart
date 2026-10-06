import 'package:flutter/material.dart';
import '../../agent/ask_user_tool.dart';
import 'question_sheet.dart';
import 'user_question_answer.dart';
import 'user_question_skip_button.dart';

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
  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) => QuestionSheetLayout(
    title: widget.question.title ?? '问题',
    trailing: UserQuestionSkipButton(question: widget.question),
    sender: widget.showSender ? widget.question.sender : null,
    onOpenSender: widget.onOpenSender,
    child: UserQuestionAnswer(question: widget.question),
  );
}
