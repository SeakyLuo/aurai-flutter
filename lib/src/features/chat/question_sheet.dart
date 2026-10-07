import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import '../../app/global_ui.dart';
import '../../domain/message_sender.dart';
import 'app_sheet_surface.dart';
import 'member_avatar.dart';
import 'question_icon.dart';
import 'question_options_sheet.dart';
import 'thinking_indicator.dart';
import 'user_question_option_tile.dart';

Future<void> showQuestionSheet(
  BuildContext context, {
  required Widget child,
  Future<void>? closeWhen,
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
      child: child,
    ),
  );
  closeWhen?.then((_) {
    if (!route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  });
  await navigator.push(route);
  // A popped sheet still owns its input focus until its exit finishes.
  await route.completed;
}

class QuestionSheetLayout extends StatelessWidget {
  const QuestionSheetLayout({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
    this.sender,
    this.onOpenSender,
    this.heading,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final MessageSender? sender;
  final VoidCallback? onOpenSender;
  final Widget? heading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                    if (heading == null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: kMinInteractiveDimension,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ThinkingIndicator(
                                label: title,
                                animate: false,
                                singleLine: true,
                                leading: SizedBox.square(
                                  dimension: MediaQuery.textScalerOf(
                                    context,
                                  ).scale(18),
                                  child: const FittedBox(
                                    child: QuestionIcon(
                                      type: QuestionIconType.question,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (trailing case final trailing?) ...[
                              const SizedBox(width: 12),
                              trailing,
                            ],
                          ],
                        ),
                      ),
                    if (sender case final sender?)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Semantics(
                          button: true,
                          label: '查看${sender.displayName}的资料',
                          child: InkWell(
                            onTap: onOpenSender,
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                MemberAvatar(sender: sender, size: 24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: sender.displayName,
                                          style: TextStyle(
                                            color: GlobalUI.highlightTextColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                        const TextSpan(text: '问了你一个问题'),
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
                        child: heading == null
                            ? child
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [heading!, child],
                              ),
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

class QuestionAnswerContent extends StatelessWidget {
  const QuestionAnswerContent({
    super.key,
    required this.question,
    required this.options,
    required this.selected,
    this.onSelect,
    this.onChooseOptions,
    this.compactOptions = false,
    this.multiple = false,
    this.footer,
    this.showQuestion = true,
  });

  final String question;
  final List<UserQuestionOption> options;
  final Set<int> selected;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onChooseOptions;
  final bool compactOptions, multiple;
  final Widget? footer;
  final bool showQuestion;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showQuestion)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Text(
            question,
            style: const TextStyle(
              fontSize: 17,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      if (compactOptions && options.length > 5)
        QuestionOptionsField(
          label: '选择回答（${options.length} 项）',
          onTap: onChooseOptions,
        )
      else
        for (final (index, option) in options.indexed)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == options.length - 1 ? 0 : 8,
            ),
            child: UserQuestionOptionTile(
              option: option,
              number: index + 1,
              selected: selected.contains(index),
              multiple: multiple,
              onTap: onSelect == null ? null : () => onSelect!(index),
            ),
          ),
      if (footer case final footer?) footer,
    ],
  );
}
