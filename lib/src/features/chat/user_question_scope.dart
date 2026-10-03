import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';

class UserQuestionScope extends InheritedNotifier<ValueNotifier<bool>> {
  UserQuestionScope({
    super.key,
    required this.question,
    required this.onOpen,
    required super.child,
  }) : super(notifier: question?.sheetVisible);

  final UserQuestion? question;
  final VoidCallback onOpen;

  static UserQuestionScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UserQuestionScope>();

  @override
  bool updateShouldNotify(UserQuestionScope oldWidget) =>
      !identical(question, oldWidget.question);
}
