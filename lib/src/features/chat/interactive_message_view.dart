import '../../app/glass_notice.dart';
import '../../storage/interactive_selection_drafts.dart';
import 'interactive_button_layout.dart';
import 'interaction_content.dart';
import '../../domain/error_message.dart';
import 'interactive_message_button.dart';
import 'package:flutter/material.dart';
import '../../domain/interactive_message.dart';
import '../../domain/message_sender.dart';
import '../../app/global_ui.dart';
import '../../domain/interactive_selection.dart';
import '../../agent/ask_user_tool.dart';
import 'question_sheet.dart';
import 'vote_message_heading.dart';
import 'vote_selection_hint.dart';
import 'question_message_heading.dart';
import 'question_batch_card.dart';
import 'dart:convert';

class InteractiveMessageView extends StatefulWidget {
  const InteractiveMessageView({
    super.key,
    this.messageId,
    required this.card,
    required this.onClick,
    required this.onOpenLink,
    this.actorId = 'user:local',
    this.readOnly = false,
    this.titleTrailing,
    this.historical = false,
    this.onRetry,
    this.onCancelVote,
    this.onStatistics,
    this.members = const {},
    this.onOpenMember,
    this.showQuestionRecipient = true,
  });
  final InteractiveMessage card;
  final String? messageId;
  final Map<String, MessageSender> members;
  final ValueChanged<String>? onOpenMember;
  final VoidCallback? onStatistics;
  final String actorId;
  final bool readOnly;
  final bool historical;
  final bool showQuestionRecipient;
  final Future<InteractiveMessage> Function(String eventId)? onRetry;
  final Future<InteractiveMessage> Function(
    int revision,
    int participantRevision,
  )?
  onCancelVote;
  final Widget? titleTrailing;
  final Future<InteractiveClickResult?> Function(
    String buttonId,
    int revision,
    int participantRevision, {
    Object? value,
  })
  onClick;
  final Future<void> Function(String url) onOpenLink;
  @override
  State<InteractiveMessageView> createState() => _InteractiveMessageViewState();
}

class _InteractiveMessageViewState extends State<InteractiveMessageView> {
  String? _busy;
  late InteractiveMessage _card = widget.card;

  @override
  void didUpdateWidget(InteractiveMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.actorId != oldWidget.actorId) {
      _card = widget.card;
    } else {
      _acceptCard(widget.card);
    }
  }

  void _acceptCard(InteractiveMessage next) {
    if (next.revision > _card.revision ||
        (next.revision == _card.revision &&
            next.participantRevision(widget.actorId) >=
                _card.participantRevision(widget.actorId) &&
            next.sessionVersion >= _card.sessionVersion &&
            (next.participantRevision(widget.actorId) >
                    _card.participantRevision(widget.actorId) ||
                ((next.participants[widget.actorId]?['callback']
                                as Map?)?['updatedAt']
                            as int? ??
                        0) >=
                    ((_card.participants[widget.actorId]?['callback']
                                as Map?)?['updatedAt']
                            as int? ??
                        0)))) {
      _card = next;
    }
  }

  Future<void> _click(Map<String, Object?> button, {Object? value}) async {
    if (_busy != null) return;
    setState(() => _busy = button['id'] as String);
    try {
      final result = await widget.onClick(
        button['id'] as String,
        _card.revision,
        _card.participantRevision(widget.actorId),
        value: value,
      );
      if (result != null &&
          widget.messageId != null &&
          (button['selection'] != null || button['questions'] != null)) {
        await InteractiveSelectionDrafts.instance.save(
          widget.messageId!,
          widget.actorId,
          button['id'] as String,
          '',
          {},
        );
      }
      if (result != null && mounted) {
        setState(() {
          _acceptCard(result.card);
        });
        if (result.url != null) await widget.onOpenLink(result.url!);
      }
    } on Object catch (error) {
      if (mounted && error is InteractiveMessageChanged)
        setState(() => _acceptCard(error.card));
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : '操作失败，请重试：${errorMessage(error)}',
            ),
          ),
          kind: ToastKind.error,
        );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _saveSelection(
    String buttonId,
    String version,
    Set<String> selected,
    String otherText,
  ) async {
    try {
      await InteractiveSelectionDrafts.instance.save(
        widget.messageId!,
        widget.actorId,
        buttonId,
        version,
        selected,
        otherText: otherText,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
      }
    }
  }

  Future<void> _retry(String eventId) async {
    if (_busy != null) return;
    setState(() => _busy = eventId);
    try {
      final card = await widget.onRetry!(eventId);
      if (mounted)
        setState(() {
          _acceptCard(card);
        });
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _cancelVote() async {
    if (_busy != null) return;
    setState(() => _busy = 'cancelVote');
    try {
      final card = await widget.onCancelVote!(
        _card.revision,
        _card.participantRevision(widget.actorId),
      );
      if (mounted) setState(() => _acceptCard(card));
    } on Object catch (error) {
      if (mounted && error is InteractiveMessageChanged)
        setState(() => _acceptCard(error.card));
      if (mounted)
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text(errorMessage(error))),
          kind: ToastKind.error,
        );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final card = _card.viewFor(widget.actorId);
    final selected = _card.participants[widget.actorId];
    final callback = selected?['callback'] as Map?;
    final callbackStatus = callback?['status'];
    final callbackLocked = ['queued', 'processing'].contains(callbackStatus);
    final pendingButtonId = callbackLocked
        ? (callback?['buttonId'] ?? selected?['buttonId']) as String?
        : null;
    final canRetry =
        !widget.readOnly &&
        !widget.historical &&
        _card.snapshotView == null &&
        widget.onRetry != null;
    final sharedView = widget.historical
        ? _card.snapshotView
        : _card.hasInteraction
        ? _card.interactionView(widget.actorId)
        : null;
    final vote = _card.isVote;
    final ongoingVote =
        vote &&
        !card.closed &&
        sharedView?['phase'] == 'collecting' &&
        sharedView?['closed'] != true &&
        sharedView?['completed'] != true;
    final multiple = card.buttons.any(
      (button) => (button['selection'] as Map?)?['mode'] == 'multiple',
    );
    final voteSelection = vote
        ? card.buttons
              .where((button) => button['selection'] != null)
              .firstOrNull
        : null;
    final voteConfig = voteSelection == null
        ? null
        : InteractiveSelection(
            Map<String, Object?>.from(voteSelection['selection'] as Map),
          );
    final selectionHint = voteConfig == null || !voteConfig.multiple
        ? null
        : voteSelectionHint(voteConfig.minimum, voteConfig.maximum);
    final repeatedSelectionBody =
        selectionHint != null &&
        (card.body == selectionHint || card.body == '$selectionHint。');
    final question = _card.isQuestion;
    final recipient = question && widget.showQuestionRecipient
        ? widget.members[(_card.interaction['actors'] as List?)?.single]
        : null;
    final answered =
        sharedView?['self'] != null ||
        (sharedView?['choices'] as List?)?.isNotEmpty == true ||
        sharedView?['submittedCount'] == 1;
    final selecting =
        sharedView != null &&
        sharedView['phase'] == 'collecting' &&
        sharedView['closed'] != true &&
        sharedView['submitted'] != true &&
        !widget.readOnly &&
        !widget.historical &&
        _card.snapshotView == null &&
        (!_card.shared ||
            _card.interaction['actors'] == null ||
            (_card.interaction['actors'] as List).contains(widget.actorId)) &&
        card.buttons.any((button) => button['selection'] != null);
    final statisticsVisible =
        _card.hasInteraction &&
        !selecting &&
        card.showStatistics &&
        (widget.historical && _card.snapshotView != null
            ? _card.snapshotView!['summaryVisible'] == true
            : _card.visible('summaryVisibility', actor: widget.actorId));
    final hiddenVoteOptions =
        vote &&
        (sharedView?['components'] as List? ?? const []).any(
          (component) =>
              component['type'] == 'distribution' &&
              InteractionDistribution.hidesOptions(
                component['items'] as List,
                hideZeroVotes:
                    sharedView?['closed'] == true ||
                    sharedView?['phase'] == 'closed' ||
                    sharedView?['completed'] == true,
              ),
        );
    final answer = question
        ? ((sharedView?['self'] as Map?) ??
              ((sharedView?['choices'] as List?)?.firstOrNull as Map?))
        : null;
    final compactAnswered = question && answer != null;
    final batchButton = card.buttons
        .where((button) => button['questions'] != null)
        .firstOrNull;
    if (batchButton != null) {
      final readOnly =
          widget.readOnly ||
          widget.historical ||
          _card.snapshotView != null ||
          card.closed ||
          sharedView?['phase'] != 'collecting' ||
          !(_card.interaction['actors'] as List).contains(widget.actorId);
      return QuestionBatchCard(
        key: ValueKey((widget.messageId, widget.actorId)),
        questions: batchButton['questions'] as List,
        buttonId: batchButton['id'] as String,
        actorId: widget.actorId,
        version: jsonEncode([card.revision, batchButton['questions']]),
        messageId: widget.messageId,
        answer: answer,
        readOnly: readOnly,
        recipient: recipient,
        onOpenMember: widget.onOpenMember,
        trailing: widget.titleTrailing,
        status: answered
            ? '已回答'
            : card.closed || sharedView?['completed'] == true
            ? '已结束'
            : '待回答',
        onSubmit: (value) => _click(batchButton, value: value),
        onSave: (version, data) =>
            _saveSelection(batchButton['id'] as String, version, {}, data),
      );
    }
    Widget questionHeading() => QuestionMessageHeading(
      title: card.title,
      description: card.body,
      multiple: multiple,
      recipient: recipient,
      status: answered
          ? '已回答'
          : card.closed
          ? '已结束'
          : '待回答',
      onOpenMember: widget.onOpenMember,
      trailing: widget.titleTrailing,
    );
    Future<void> openAnsweredQuestion() async {
      final button = card.buttons.singleWhere(
        (button) => button['id'] == answer!['buttonId'],
      );
      final config = InteractiveSelection(
        Map<String, Object?>.from(button['selection'] as Map),
      );
      await showQuestionSheet(
        context,
        child: Builder(
          builder: (context) => QuestionSheetLayout(
            title: card.title,
            heading: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: questionHeading(),
            ),
            child: QuestionAnswerContent(
              question: card.body,
              showQuestion: false,
              options: [
                for (final option in config.options)
                  UserQuestionOption(content: option['label'] as String),
              ],
              selected: {
                for (final (index, option) in config.options.indexed)
                  if ((answer!['selections'] as List).any(
                    (selected) => selected['optionId'] == option['id'],
                  ))
                    index,
              },
              multiple: config.multiple,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: compactAnswered ? openAnsweredQuestion : null,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vote)
              VoteMessageHeading(
                title: card.title,
                multiple: multiple,
                ongoing: ongoingVote,
                anonymous: card.anonymous,
                status: card.closed || sharedView?['closed'] == true
                    ? '已结束'
                    : sharedView?['completed'] == true
                    ? '已完成'
                    : '进行中',
                trailing: widget.titleTrailing,
              )
            else if (question)
              questionHeading()
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: card.title),
                          if (multiple)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(
                                      alpha: .22,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      '多选',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: GlobalUI.highlightTextColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  if (widget.titleTrailing case final trailing?) trailing,
                ],
              ),
            if (!question &&
                card.body.isNotEmpty &&
                !(repeatedSelectionBody && selecting)) ...[
              const SizedBox(height: 8),
              Text(
                card.body,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: colors.onSurface,
                ),
              ),
            ],
            if (sharedView == null &&
                (card.closed || (card.singleChoice && selected != null))) ...[
              const SizedBox(height: 12),
              Text(
                [
                  if (card.closed) '已结束',
                  if (card.singleChoice && selected != null)
                    '已选：${selected['label']}',
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
            if (callbackStatus == 'failed') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showToast(
                        SnackBar(content: Text(callback!['error'] as String)),
                        kind: ToastKind.error,
                      ),
                      child: Text(
                        '处理未完成',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  if (canRetry)
                    TextButton(
                      onPressed: _busy == null
                          ? () => _retry(callback!['id'] as String)
                          : null,
                      child: const Text('重试'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (sharedView != null)
              InteractionContent(
                key: ValueKey((widget.actorId, card.title, card.body)),
                draftOwner:
                    widget.messageId == null ||
                        widget.readOnly ||
                        widget.historical ||
                        _card.snapshotView != null
                    ? null
                    : (
                        messageId: widget.messageId!,
                        actorId: widget.actorId,
                        revision: _card.participantRevision(widget.actorId),
                      ),
                onSaveSelection: _saveSelection,
                view: sharedView,
                statusInHeading: vote,
                members: widget.members,
                onOpenMember: widget.onOpenMember,
                onStatistics: widget.onStatistics,
                question: question,
                compactOptions: question || vote,
                title: card.title,
                body: card.body,
                shared: _card.shared,
                buttons: card.buttons,
                buttonColumns: card.buttonColumns,
                readOnly:
                    widget.readOnly ||
                    widget.historical ||
                    _card.snapshotView != null,
                pendingButtonId: pendingButtonId,
                allowChange: _card.hasInteraction && _card.engine.allowChange,
                eligible:
                    !_card.shared ||
                    _card.interaction['actors'] == null ||
                    (_card.interaction['actors'] as List).contains(
                      widget.actorId,
                    ),
                busy: _busy,
                onClick: _click,
                onCancelVote: vote && widget.onCancelVote != null
                    ? _cancelVote
                    : null,
              )
            else
              InteractiveButtonLayout(
                columns: card.buttonColumns,
                children: [
                  for (final button in card.buttons)
                    InteractiveMessageButton(
                      button: button,
                      busy: _busy == button['id'],
                      locked:
                          _busy != null ||
                          widget.readOnly ||
                          card.closed ||
                          pendingButtonId == button['id'],
                      onPressed: () => _click(button),
                    ),
                ],
              ),
            if (statisticsVisible && widget.onStatistics != null) ...[
              const SizedBox(height: 12),
              InteractiveMessageButton(
                button: {
                  'label': sharedView?['submitted'] != true && hiddenVoteOptions
                      ? '查看全部选项'
                      : '查看详情',
                  'icon': 'none',
                },
                busy: false,
                locked: false,
                onPressed: compactAnswered
                    ? openAnsweredQuestion
                    : widget.onStatistics!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
