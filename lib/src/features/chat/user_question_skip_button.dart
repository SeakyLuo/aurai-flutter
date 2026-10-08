import 'dart:async';

import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import 'question_submission.dart';

class QuestionSkipStyle extends InheritedWidget {
  const QuestionSkipStyle({
    super.key,
    required this.compact,
    required super.child,
  });
  final bool compact;
  static bool compactOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<QuestionSkipStyle>()
          ?.compact ??
      false;
  @override
  bool updateShouldNotify(QuestionSkipStyle oldWidget) =>
      compact != oldWidget.compact;
}

class UserQuestionSkipButton extends StatefulWidget {
  const UserQuestionSkipButton({super.key, required this.question});
  final UserQuestion question;

  @override
  State<UserQuestionSkipButton> createState() => _UserQuestionSkipButtonState();
}

class _UserQuestionSkipButtonState extends State<UserQuestionSkipButton> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final remaining = widget.question.expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) return;
    final delay = remaining >= const Duration(hours: 1)
        ? remaining - const Duration(hours: 1) + const Duration(seconds: 1)
        : const Duration(seconds: 1);
    _timer = Timer(delay, () {
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final remaining = question.expiresAt.difference(DateTime.now());
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    final countdown = seconds > 0 && remaining < const Duration(hours: 1)
        ? remaining < const Duration(minutes: 1)
              ? ' $seconds 秒'
              : ' ${(seconds / 60).ceil()} 分钟'
        : null;
    return QuestionSkipButton(
      countdown: countdown,
      onPressed: question.result.isCompleted
          ? null
          : () {
              FocusScope.of(context).unfocus();
              if (question.batch != null) {
                submitQuestionAnswers(context, question, {
                  'skipQuestions': true,
                });
              } else {
                question.answer(skipped: true);
              }
            },
    );
  }
}

class QuestionSkipButton extends StatelessWidget {
  const QuestionSkipButton({
    super.key,
    required this.onPressed,
    this.countdown,
  });

  final VoidCallback? onPressed;
  final String? countdown;

  @override
  Widget build(BuildContext context) {
    final compact = QuestionSkipStyle.compactOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: compact
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
            minimumSize: compact ? const Size(48, 28) : const Size(56, 32),
            tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 8)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            shape: StadiumBorder(
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: .35),
              ),
            ),
            textStyle: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          onPressed: onPressed,
          child: Tooltip(
            message: countdown == null ? '跳过' : '跳过$countdown',
            child: const Text('跳过'),
          ),
        ),
        if (countdown != null && !compact)
          Text(
            countdown!,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
