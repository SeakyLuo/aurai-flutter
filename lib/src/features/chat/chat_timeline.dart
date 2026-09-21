import 'private_reply_layout.dart';
import 'interactive_message_paging.dart';
import 'recalled_message_notice.dart';
import '../../html_games/html_game_view.dart';
import '../../domain/tool_activity_groups.dart';
import 'tool_activity_group.dart';
import 'task_elapsed.dart';
import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import '../../domain/web_sources.dart';
import 'chat_controller.dart';
import 'message_item.dart';
import 'group_message_heading.dart';
import 'ai_contact_page.dart';
import '../../domain/message_sender.dart';
import 'message_time.dart';
import 'tool_activity_view.dart';

class ChatTimelineEntry {
  const ChatTimelineEntry(this.id, this.builder);
  final String id;
  final WidgetBuilder builder;
}

List<ChatTimelineEntry> buildChatTimeline(
  ChatController controller, {
  required Future<void> Function(AgentMessage) onEdit,
  String? beforeMessageId,
  String? highlightedMessageId,
  bool allowEditing = true,
  ValueChanged<AgentMessage>? onQuote,
  ValueChanged<MessageSender>? onMention,
  Future<void> Function(AgentMessage)? onRecall,
  ValueChanged<String>? onOpenQuote,
  ValueChanged<AgentMessage>? onReeditRecalled,
  Future<void> Function(AgentMessage, String)? onQuickReply,
}) {
  final conversation = controller.activeConversation;
  final mentionSenders = {
    for (final sender in conversation.creationMembers) sender.id: sender,
    for (final message in [
      ...conversation.messages,
      ...?conversation.searchMessages,
    ])
      if (message.sender != null) message.sender!.id: message.sender!,
  };
  final mentionMembers = <String, String>{};
  final ambiguousNames = <String>{};
  for (final sender in mentionSenders.values) {
    if (mentionMembers.containsKey(sender.name))
      ambiguousNames.add(sender.name);
    mentionMembers[sender.name] = sender.id;
  }
  mentionMembers.removeWhere((name, _) => ambiguousNames.contains(name));
  final isGroup = conversation.kind == ConversationKind.group;
  final richRuns = isGroup
      ? <String>{}
      : richReplyRuns(controller.visibleMessages);
  final watch = conversation.executionWatch;
  final showElapsed =
      !isGroup &&
      watch != null &&
      conversation.hasExecutionProcess &&
      (watch.isRunning || conversation.runState == ChatRunState.failed) &&
      !controller.visibleMessages.any(
        (message) =>
            message.runId == conversation.activeRunId &&
            message.taskSummary != null,
      );
  final reasoningIds = {
    for (final message in controller.visibleMessages)
      if (message.isReasoning) message.id,
  };
  final hiddenIds = {
    for (final message in controller.visibleMessages)
      if (!isGroup && message.taskSummary != null)
        for (final id in message.taskSummary!.intermediateMessageIds)
          if (reasoningIds.contains(id) || !richRuns.contains(message.runId))
            id,
  };
  final toolsByMessage = <String, List<ChatTimelineEntry>>{};
  final members = controller.groupRuns.toList();
  final liveSteps = [
    if (!isGroup && members.isEmpty)
      for (final (ordinal, entry) in conversation.liveToolSteps.indexed)
        (
          ordinal: ordinal,
          afterMessageId: entry.afterMessageId,
          step: entry.step,
          runId: conversation.activeRunId,
          senderName: null as String?,
        )
    else if (!isGroup)
      for (final member in members)
        for (final (ordinal, entry) in member.liveToolSteps.indexed)
          (
            ordinal: ordinal,
            afterMessageId: entry.afterMessageId,
            step: entry.step,
            runId: member.activeRunId,
            senderName: member.replyingSenderName,
          ),
  ];
  final memberSources = {
    for (final member in members.where((_) => !isGroup))
      member.activeRunId: webSourcesFromSteps(
        member.liveToolSteps.map((entry) => entry.step),
      ),
  };
  final liveSources = webSourcesFromSteps(liveSteps.map((entry) => entry.step));
  final groups = toolActivityGroups([
    for (final entry in liveSteps)
      entry.step.toolName == 'askUser'
          ? null
          : '${entry.runId}:${entry.afterMessageId}:${entry.step.toolName}',
  ]);
  for (final group in groups) {
    final entry = liveSteps[group.start];
    final storageId = 'tool:${entry.runId}:${entry.ordinal}';
    toolsByMessage
        .putIfAbsent(entry.afterMessageId, () => [])
        .add(
          ChatTimelineEntry(
            storageId,
            (_) => group.end - group.start == 1
                ? _ToolActivity(
                    storageId: storageId,
                    step: entry.step,
                    senderName: entry.senderName,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                    child: ToolActivityGroup(
                      key: ValueKey(storageId),
                      storageId: storageId,
                      toolName: entry.step.toolName,
                      statuses: [
                        for (var i = group.start; i < group.end; i++)
                          liveSteps[i].step.status,
                      ],
                      children: [
                        for (var i = group.start; i < group.end; i++)
                          _ToolActivity(
                            storageId:
                                'tool:${liveSteps[i].runId}:${liveSteps[i].ordinal}',
                            senderName: liveSteps[i].senderName,
                            step: liveSteps[i].step,
                            grouped: true,
                          ),
                      ],
                    ),
                  ),
          ),
        );
  }
  final visibleMessages = controller.visibleMessages
      .where(
        (message) =>
            !(message.isSystem && message.text == '私密交互消息已更新') &&
            (message.interactive?.canView(MessageSender.localUser.id) ??
                true) &&
            (!hiddenIds.contains(message.id) ||
                message.id == conversation.searchMessageId),
      )
      .toList();
  final end = beforeMessageId == null
      ? visibleMessages.length
      : visibleMessages.indexWhere((message) => message.id == beforeMessageId);
  final replyParts = isGroup
      ? <String, PrivateReplyPart>{}
      : privateReplyLayout(
          visibleMessages.take(end < 0 ? visibleMessages.length : end).toList(),
          richRuns,
        );
  return [
    if (conversation.kind == ConversationKind.group &&
        !(conversation.searchMessages != null
            ? conversation.searchHasEarlier
            : conversation.hasEarlierMessages))
      ChatTimelineEntry(
        'creation:${conversation.id}',
        (context) => Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
          child: Column(
            children: [
              Text(
                messageTime(conversation.createdAt),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (conversation.creationMembers.isNotEmpty &&
                  !visibleMessages.any(
                    (m) => m.id == 'group-created:${conversation.id}',
                  )) ...[
                const SizedBox(height: 24),
                Text(
                  conversation.creationMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    for (final (index, message)
        in visibleMessages
            .take(end + (beforeMessageId == null ? 0 : 1))
            .indexed) ...[
      if (index > 0 &&
          (replyParts[message.id]?.first ?? true) &&
          message.createdAt.difference(visibleMessages[index - 1].createdAt) >
              const Duration(minutes: 30))
        ChatTimelineEntry(
          'time:${message.id}',
          (context) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
            child: Center(
              child: Text(
                messageTime(message.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      if (message.id != beforeMessageId)
        ChatTimelineEntry(message.id, (context) {
          if (message.isSystem) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                28,
                12,
                28,
                conversation.kind == ConversationKind.group ? 0 : 12,
              ),
              child: RecalledMessageNotice(
                message: message,
                onEdit: onReeditRecalled,
                onOpenSource: onOpenQuote,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final content = MessageItem(
            excludedActivityMessageId: conversation.searchMessageId,
            key: ValueKey(message.id),
            message: message,
            replyPart: replyParts[message.id],
            mentionMembers: mentionMembers,
            htmlGameView: message.htmlGame == null
                ? null
                : HtmlGameView(
                    card: message.htmlGame!,
                    messageId: message.id,
                    conversationId: conversation.id,
                    store: controller.htmlGames,
                  ),
            onInteractiveRetry: (eventId) =>
                controller.retryInteractiveCallback(message.id, eventId),
            onInteractiveClick:
                (button, revision, participantRevision, {value}) =>
                    controller.clickInteractiveMessage(
                      message.id,
                      button,
                      revision,
                      participantRevision,
                      value: value,
                    ),
            groupBubble: conversation.kind == ConversationKind.group,
            onQuote:
                conversation.kind == ConversationKind.group &&
                    !controller.isStreamingMessage(message.id) &&
                    (message.text.isNotEmpty ||
                        message.images.isNotEmpty ||
                        message.files.isNotEmpty)
                ? onQuote
                : null,
            onOpenQuote: onOpenQuote,
            onOpenMember: (id) {
              if (id == MessageSender.localUser.id) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AiContactPage(
                    controller: controller,
                    senderId: id,
                    groupId: conversation.id,
                  ),
                ),
              );
            },
            onQuickReply:
                !message.isSystem &&
                    !message.isReasoning &&
                    message.interactive?.systemPresentation != true &&
                    (message.role == AgentMessageRole.assistant ||
                        message.senderId == MessageSender.localUser.id)
                ? onQuickReply
                : null,
            availableSources:
                memberSources[message.runId] ??
                (message.runId != null &&
                        message.runId == conversation.activeRunId
                    ? liveSources
                    : const {}),
            onRecall:
                conversation.kind == ConversationKind.group &&
                    message.senderId == MessageSender.localUser.id
                ? onRecall
                : null,
            onEdit: allowEditing && conversation.kind != ConversationKind.group
                ? onEdit
                : null,
            streaming:
                controller.isStreamingMessage(message.id) ||
                (members.isEmpty &&
                    controller.isBusy &&
                    message.runId == controller.activeConversation.activeRunId),
          );
          final messageBody =
              conversation.kind == ConversationKind.group &&
                  message.role == AgentMessageRole.assistant &&
                  message.sender != null &&
                  message.interactive?.systemPresentation != true
              ? GroupMessageHeading(
                  showName: message.htmlGame == null,
                  isFailure: message.isFailure,
                  sender: message.sender!,
                  onMention: onMention == null
                      ? null
                      : () => onMention(message.sender!),
                  onOpenProfile: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiContactPage(
                        controller: controller,
                        senderId: message.sender!.id,
                        groupId: conversation.id,
                      ),
                    ),
                  ),
                  child: content,
                )
              : content;
          final systemBody =
              message.interactive?.systemPresentation == true &&
                  message.htmlGame == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '系统',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      messageBody,
                    ],
                  ),
                )
              : messageBody;
          final pagedBody =
              message.interactive == null || message.htmlGame != null
              ? systemBody
              : InteractiveMessagePaging(
                  key: ValueKey('pages:${message.id}'),
                  messageId: message.id,
                  card: message.interactive!,
                  database: controller.groupStore.database,
                  child: systemBody,
                );
          final item = conversation.kind == ConversationKind.group
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: pagedBody,
                )
              : pagedBody;
          if (message.id != highlightedMessageId) return item;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: .28, end: 0),
            duration: const Duration(seconds: 4),
            curve: const Interval(.5, 1, curve: Curves.easeOut),
            builder: (context, opacity, child) => DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: opacity),
              ),
              child: child,
            ),
            child: SizedBox(width: double.infinity, child: item),
          );
        }),
      if (showElapsed &&
          message.id == conversation.executionUserMessageId &&
          message.id != beforeMessageId)
        ChatTimelineEntry(
          'elapsed:${conversation.activeRunId}',
          (_) => TaskElapsed(
            key: ValueKey(conversation.activeRunId),
            watch: watch,
            restoredElapsed: conversation.restoredExecutionElapsed,
            failed: conversation.runState == ChatRunState.failed,
          ),
        ),
      if (!isGroup && message.id != beforeMessageId)
        ...?toolsByMessage[message.id],
    ],
  ];
}

Map<String, String> chatSummaryOwners(ChatController controller) {
  final richRuns = controller.activeConversation.kind == ConversationKind.group
      ? <String>{}
      : richReplyRuns(controller.visibleMessages);
  final reasoningIds = {
    for (final message in controller.visibleMessages)
      if (message.isReasoning) message.id,
  };
  return {
    for (final message in controller.visibleMessages)
      'time:${message.id}': message.id,
    for (final message in controller.visibleMessages)
      if (message.taskSummary != null) ...{
        'elapsed:${message.runId}': message.id,
        for (final id in message.taskSummary!.intermediateMessageIds)
          if (id != controller.activeConversation.searchMessageId &&
              (reasoningIds.contains(id) || !richRuns.contains(message.runId)))
            id: message.id,
        for (var i = 0; i < message.taskSummary!.activities.length; i++)
          'tool:${message.runId}:$i': message.id,
        if (message.runId == controller.activeConversation.activeRunId)
          'progress:${controller.activeConversation.id}': message.id,
      },
  };
}

class _ToolActivity extends StatelessWidget {
  const _ToolActivity({
    required this.step,
    required this.storageId,
    this.grouped = false,
    this.senderName,
  });
  final bool grouped;
  final String? senderName;
  final String storageId;

  final AgentStep step;

  @override
  Widget build(BuildContext context) {
    final prefix = switch (step.status) {
      AgentStepStatus.running => '正在',
      AgentStepStatus.completed => '已完成：',
      AgentStepStatus.failed => '未完成：',
      AgentStepStatus.cancelled => '已停止：',
    };
    return Padding(
      padding: grouped
          ? const EdgeInsets.symmetric(vertical: 5)
          : const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: ToolActivityView(
        toolName: step.toolName,
        storageId: storageId,
        title:
            '${senderName == null ? '' : '$senderName '}$prefix${step.title}',
        status: step.status,
        requestJson: step.requestJson,
        resultJson: step.resultJson,
      ),
    );
  }
}
