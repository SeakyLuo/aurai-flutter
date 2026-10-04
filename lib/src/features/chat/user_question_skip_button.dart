import 'dart:async';

import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            minimumSize: const Size(56, 32),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            shape: StadiumBorder(
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: .35),
              ),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          onPressed: question.result.isCompleted
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  question.answer(skipped: true);
                },
          child: Text('跳过'),
        ),
        if (countdown != null)
          Text(
            countdown,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
