import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import 'image_action_scope.dart';
import 'chat_controller.dart';

import '../../domain/interactive_message.dart';
import '../../domain/interactive_questionnaire.dart';
import '../../domain/message_sender.dart';
import '../../storage/interactive_selection_drafts.dart';
import 'interactive_message_button.dart';
import 'interactive_selection_view.dart';
import 'participation_summary.dart';
import 'question_batch_card.dart';
import 'question_sheet.dart';
import 'questionnaire_response_list.dart';
import 'vote_message_heading.dart';

class QuestionnaireCardView extends StatefulWidget {
  const QuestionnaireCardView({
    super.key,
    required this.card,
    required this.actorId,
    required this.readOnly,
    required this.fullSheet,
    required this.busy,
    required this.onClick,
    required this.onSave,
    required this.members,
    this.messageId,
    this.pendingButtonId,
    this.trailing,
    this.onStatistics,
    this.onOpenMember,
  });
  final InteractiveMessage card;
  final String actorId;
  final String? messageId, busy, pendingButtonId;
  final bool readOnly, fullSheet;
  final Widget? trailing;
  final Map<String, MessageSender> members;
  final VoidCallback? onStatistics;
  final ValueChanged<String>? onOpenMember;
  final Future<void> Function(Map<String, Object?>, {Object? value}) onClick;
  final Future<void> Function(String, String, Set<String>, String) onSave;
  @override
  State<QuestionnaireCardView> createState() => _QuestionnaireCardViewState();
}

class _QuestionnaireCardViewState extends State<QuestionnaireCardView> {
  bool _editing = false;
  bool _changingCollection = false;

  Future<void> _toggleCollection() async {
    final controller = ImageActionScope.of(context);
    setState(() => _changingCollection = true);
    await runUiAction(context, () async {
      await controller.setQuestionnairePaused(
        widget.messageId!,
        widget.card.revision,
        !widget.card.collectionPaused,
      );
    });
    if (mounted) setState(() => _changingCollection = false);
  }

  @override
  void didUpdateWidget(QuestionnaireCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card.participantRevision(widget.actorId) !=
            oldWidget.card.participantRevision(widget.actorId) ||
        widget.card.revision != oldWidget.card.revision)
      _editing = false;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final view = card.interactionView(widget.actorId);
    final definition = card.viewFor(widget.actorId).buttons.single;
    // A single question uses its own confirmation rule; question groups submit together.
    final button = definition;
    final actors = card.interaction['actors'] as List?;
    final eligible = actors == null || actors.contains(widget.actorId);
    final own = view['self'] as Map?;
    final submitted = view['submitted'] == true;
    final answersVisible = card.snapshotView != null
        ? view['submissions'] is Map
        : card.visible('visibility', actor: widget.actorId);
    final ongoing = view['phase'] == 'collecting' && view['closed'] != true;
    final canEdit =
        eligible &&
        ongoing &&
        !card.collectionPaused &&
        !widget.readOnly &&
        (!submitted || card.engine.allowChange);
    final editing = canEdit && (!submitted || _editing);
    final version = jsonEncode([
      view['round'],
      button['selection'] ?? button['questions'],
    ]);
    final status = card.completed
        ? '已结束'
        : card.collectionPaused
        ? '已暂停'
        : '进行中';
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final heading = VoteMessageHeading(
      title: card.title,
      multiple: false,
      ongoing: ongoing,
      anonymous: false,
      questionnaire: true,
      status: status,
      trailing: widget.trailing,
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        heading,
        if (card.body.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(card.body, style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
        const SizedBox(height: 12),
        Text(
          [
            if (view['summaryVisible'] == true)
              participationSummaryText(
                view['submittedCount'] as int,
                view['eligibleCount'] as int?,
                questionnaire: true,
              ),
            !eligible
                ? '不需要你参与'
                : submitted
                ? '你已填写'
                : ongoing
                ? '你还没有填写'
                : '你未填写本轮',
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: secondary),
        ),
        if (editing) ...[
          const SizedBox(height: 12),
          if (button['selection'] != null)
            InteractiveSelectionView(
              key: ValueKey((button['id'], view['round'])),
              button: button,
              self: own,
              locked: widget.busy != null || widget.pendingButtonId != null,
              submitted: false,
              allowChange: card.engine.allowChange,
              busy: widget.busy == button['id'],
              onSubmit: (value) => widget.onClick(button, value: value),
              question: true,
              questionHeading: heading,
              compactOptions: !widget.fullSheet,
              collapseOptions: true,
              title: card.title,
              body: card.body,
              draftSelection: widget.messageId == null
                  ? null
                  : InteractiveSelectionDrafts.instance.read(
                      widget.messageId!,
                      widget.actorId,
                      button['id'] as String,
                      version,
                    ),
              draftOtherText: widget.messageId == null
                  ? null
                  : InteractiveSelectionDrafts.instance.readOtherText(
                      widget.messageId!,
                      widget.actorId,
                      button['id'] as String,
                      version,
                    ),
              onSelectionChanged: widget.messageId == null
                  ? null
                  : (selected, text) => widget.onSave(
                      button['id'] as String,
                      version,
                      selected,
                      text,
                    ),
            )
          else
            QuestionBatchCard(
              key: ValueKey((widget.messageId, widget.actorId)),
              questions: button['questions'] as List,
              buttonId: button['id'] as String,
              actorId: widget.actorId,
              version: version,
              messageId: widget.messageId,
              answer: own,
              readOnly: widget.busy != null || widget.pendingButtonId != null,
              status: '待填写',
              compact: !widget.fullSheet,
              embedded: widget.fullSheet,
              sheetTitle: '填写问卷',
              questionnaire: true,
              onSubmit: (value) => widget.onClick(button, value: value),
              onSave: (version, text) =>
                  widget.onSave(button['id'] as String, version, {}, text),
            ),
          if (_editing) ...[
            const SizedBox(height: 8),
            InteractiveMessageButton(
              button: const {'label': '取消修改'},
              busy: false,
              locked: widget.busy != null,
              onPressed: () => setState(() => _editing = false),
            ),
          ],
        ] else if (eligible && own != null) ...[
          const SizedBox(height: 12),
          if (canEdit) ...[
            const SizedBox(height: 8),
            InteractiveMessageButton(
              button: const {'label': '修改回答'},
              busy: false,
              locked: widget.busy != null || widget.pendingButtonId != null,
              onPressed: () => setState(() => _editing = true),
            ),
          ],
        ],
        if (!editing && answersVisible) ...[
          const SizedBox(height: 16),
          QuestionnaireResponseList(
            card: card,
            viewerId: widget.actorId,
            members: widget.members,
            compact: true,
            onParticipant: widget.onOpenMember,
            onShowAll: widget.onStatistics,
          ),
        ] else if (!editing) ...[
          const SizedBox(height: 12),
          Text(
            questionnaireHiddenAnswersText(card, widget.actorId),
            style: TextStyle(fontSize: 12, color: secondary),
          ),
        ],
        if (card.viewFor(widget.actorId).showStatistics &&
            widget.onStatistics != null &&
            !widget.fullSheet) ...[
          const SizedBox(height: 12),
          InteractiveMessageButton(
            button: const {'label': '查看详情', 'icon': 'none'},
            busy: false,
            locked: false,
            onPressed: widget.onStatistics!,
          ),
        ],
        if (!widget.readOnly &&
            widget.messageId != null &&
            card.participation['_creatorId'] == widget.actorId &&
            !card.completed) ...[
          const SizedBox(height: 12),
          InteractiveMessageButton(
            button: {
              'label': card.collectionPaused ? '恢复收集' : '暂停收集',
              'icon': 'none',
            },
            busy: _changingCollection,
            locked:
                _changingCollection ||
                widget.busy != null ||
                widget.pendingButtonId != null,
            onPressed: _toggleCollection,
          ),
        ],
      ],
    );
    return widget.fullSheet
        ? QuestionSheetLayout(
            title: '填写问卷',
            heading: const SizedBox.shrink(),
            child: content,
          )
        : content;
  }
}
