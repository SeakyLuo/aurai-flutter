import 'app_sheet_surface.dart';
import 'package:flutter/material.dart';
import '../../app/global_ui.dart';

import '../../agent/ask_user_tool.dart';
import 'question_icon.dart';
import 'user_question_answer.dart';
import 'user_question_skip_button.dart';
import 'thinking_indicator.dart';
import 'member_avatar.dart';

Future<void> showUserQuestionSheet(
  BuildContext context, {
  required UserQuestion question,
  required bool showSender,
  required VoidCallback onOpenSender,
}) async {
  final navigator = Navigator.of(context);
  final route = ModalBottomSheetRoute<void>(
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: UserQuestionCard(
        question: question,
        showSender: showSender,
        onOpenSender: onOpenSender,
      ),
    ),
  );
  question.sheetVisible.value = true;
  try {
    await navigator.push(route);
    // A popped sheet still owns its input focus until its exit finishes.
    await route.completed;
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final question = widget.question;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: double.infinity,
          maxHeight:
              MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).top,
        ),
        child: BackdropGroup(
          child: AppSheetSurface(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ThinkingIndicator(
                            label: question.title ?? '问题',
                            animate: false,
                            singleLine: true,
                            leading: SizedBox.square(
                              dimension: MediaQuery.textScalerOf(
                                context,
                              ).scale(18),
                              child: FittedBox(
                                child: QuestionIcon(
                                  type: QuestionIconType.question,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        UserQuestionSkipButton(question: question),
                      ],
                    ),
                    if (widget.showSender)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Semantics(
                          button: true,
                          label: '查看${question.sender.name}的资料',
                          child: InkWell(
                            onTap: widget.onOpenSender,
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                MemberAvatar(sender: question.sender, size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: question.sender.name,
                                          style: TextStyle(
                                            color: GlobalUI.highlightTextColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                        TextSpan(text: '问了你一个问题'),
                                      ],
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: UserQuestionAnswer(question: question),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
