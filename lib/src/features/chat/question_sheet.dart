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
import 'rich_option_carousel.dart';
import 'question_card_anchor.dart';

Future<void> showQuestionSheet(
  BuildContext context, {
  required Widget child,
  Future<void>? closeWhen,
  String? messageId,
}) async {
  final navigator = Navigator.of(context);
  final route = ModalBottomSheetRoute<void>(
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    clipBehavior: Clip.none,
    sheetAnimationStyle: const AnimationStyle(
      curve: Curves.linear,
      reverseCurve: Curves.linear,
    ),
    constraints: const BoxConstraints(maxWidth: double.infinity),
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
    builder: (sheetContext) {
      return QuestionReturnTransition(
        hasVisibleQuestion: () =>
            QuestionCardAnchor.isVisible(context, messageId: messageId),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: child,
        ),
      );
    },
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
    this.scrollBody = true,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final MessageSender? sender;
  final VoidCallback? onOpenSender;
  final Widget? heading;
  final bool scrollBody;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: double.infinity,
          maxHeight:
              MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).top -
              MediaQuery.viewInsetsOf(context).bottom,
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
                      QuestionSenderHeading(
                        sender: sender,
                        onOpenSender: onOpenSender,
                      ),
                    Flexible(
                      child: !scrollBody
                          ? child
                          : SingleChildScrollView(
                              child: heading == null
                                  ? child
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
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
    this.optionPrefix,
    this.multiple = false,
    this.footer,
    this.showQuestion = true,
    this.allowCustomAnswer = false,
    this.customAnswer = '',
    this.onCustomAnswer,
  });

  final String question;
  final List<UserQuestionOption> options;
  final Set<int> selected;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onChooseOptions;
  final bool compactOptions, multiple;
  final String? optionPrefix;
  final Widget? footer;
  final bool showQuestion;
  final bool allowCustomAnswer;
  final String customAnswer;
  final VoidCallback? onCustomAnswer;

  @override
  Widget build(BuildContext context) {
    final choices = [
      ...options,
      if (allowCustomAnswer && options.isNotEmpty)
        UserQuestionOption(
          title: customAnswer.isEmpty ? null : '自行撰写回复',
          content: customAnswer.isEmpty ? '自行撰写回复' : customAnswer,
        ),
    ];
    final rich = choices.any((option) => option.messageId != null);
    final truncated = !rich && compactOptions && choices.length >= 5;
    final marked = {
      ...selected,
      if (allowCustomAnswer && customAnswer.isNotEmpty) options.length,
    };
    return Column(
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
        if (rich)
          RichOptionCarousel(
            options: choices,
            optionPrefix: optionPrefix,
            selected: marked,
            multiple: multiple,
            onSelect: onSelect == null
                ? null
                : (index) {
                    if (index == options.length) {
                      onCustomAnswer?.call();
                    } else {
                      onSelect!(index);
                    }
                  },
          )
        else
          for (final (index, option)
              in choices.take(truncated ? 4 : choices.length).indexed)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == choices.length - 1 ? 0 : 8,
              ),
              child: UserQuestionOptionTile(
                option: option,
                number: index + 1,
                optionPrefix: optionPrefix,
                selected: marked.contains(index),
                multiple: multiple,
                onTap: index == options.length
                    ? onCustomAnswer
                    : onSelect == null
                    ? null
                    : () => onSelect!(index),
              ),
            ),
        if (truncated) ...[
          QuestionOptionsField(label: '查看全部选项', onTap: onChooseOptions),
          if (marked.any((index) => index >= 4))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '已选：${choices.indexed.where((entry) => marked.contains(entry.$1)).map((entry) => entry.$2.content).join('、')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        if (footer case final footer?) footer,
      ],
    );
  }
}

class QuestionSenderHeading extends StatelessWidget {
  const QuestionSenderHeading({
    super.key,
    required this.sender,
    this.onOpenSender,
  });
  final MessageSender sender;
  final VoidCallback? onOpenSender;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
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
                          color: GlobalUI.highlightTextColor(context),
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
    );
  }
}
