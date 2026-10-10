import 'profile_navigation.dart';
import 'chat_message_spacing.dart';
import 'chat_timeline_entry.dart';
import 'task_message_entries.dart';
export 'chat_timeline_entry.dart';
import 'private_reply_layout.dart';
import 'interactive_message_paging.dart';
import 'recalled_message_notice.dart';
import 'task_source_notice.dart';
import '../../html_games/miniapp_forward.dart';
import '../../html_games/html_view.dart';
import '../../domain/tool_activity_groups.dart';
import 'tool_activity_group.dart';
import 'task_elapsed.dart';
import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import '../../domain/web_sources.dart';
import 'chat_controller.dart';
import 'message_item.dart';
import 'quote_focus_view.dart';
import 'group_message_heading.dart';
import 'ai_contact_page.dart';
import 'personal_info_page.dart';
import 'group_mention_text.dart';
import '../../domain/message_sender.dart';
import 'message_time.dart';
import 'timeline_tool_activity.dart';

List<ChatTimelineEntry> buildChatTimeline(
  ChatController controller, {
  required Future<void> Function(AgentMessage) onEdit,
  AgentMessage? singleMessage,
  String? beforeMessageId,
  String? highlightedMessageId,
  bool allowEditing = true,
  void Function(
    AgentMessage message, {
    String? selectedText,
    QuoteFocusVisual? visual,
  })?
  onQuote,
  ValueChanged<MessageSender>? onMention,
  Future<void> Function(AgentMessage)? onRecall,
  ValueChanged<String>? onOpenQuote,
  ValueChanged<AgentMessage>? onReeditRecalled,
  Future<void> Function(AgentMessage, String)? onQuickReply,
  Future<void> Function(AgentMessage)? onRetry,
}) {
  final conversation = controller.activeConversation;
  final timelineMessages = singleMessage == null
      ? controller.visibleMessages
      : [singleMessage];
  final mentionSenders = {
    for (final sender in conversation.creationMembers) sender.id: sender,
    for (final message in [
      ...conversation.messages,
      ...?conversation.searchMessages,
    ])
      if (message.sender != null) message.sender!.id: message.sender!,
  };
  final mentionMembers = <String, String>{};
  final interactiveMembers = {...mentionSenders, ...conversation.noticeMembers};
  final ambiguousNames = <String>{};
  for (final sender in mentionSenders.values) {
    for (final name in {sender.name, sender.displayName}) {
      if (mentionMembers.containsKey(name) && mentionMembers[name] != sender.id)
        ambiguousNames.add(name);
      mentionMembers[name] = sender.id;
    }
  }
  mentionMembers.removeWhere((name, _) => ambiguousNames.contains(name));
  final isGroup = conversation.kind == ConversationKind.group;
  final chatBubbles = isGroup || conversation.isPersonalChat;
  final noticeNameIds = <String, String>{};
  final ambiguousNoticeNames = <String>{};
  for (final sender in [
    ...mentionSenders.values,
    ...conversation.noticeMembers.values,
  ]) {
    for (final name in {
      sender.displayName,
      if (sender.originalName != null) sender.originalName!,
    }) {
      if (noticeNameIds.containsKey(name) && noticeNameIds[name] != sender.id) {
        ambiguousNoticeNames.add(name);
      }
      noticeNameIds[name] = sender.id;
    }
  }
  noticeNameIds.removeWhere((name, _) => ambiguousNoticeNames.contains(name));
  void openNoticeMember(BuildContext context, String id) {
    openProfileRoute(
      context,
      MaterialPageRoute(
        builder: (_) => id == MessageSender.localUser.id
            ? PersonalInfoPage(memory: controller.memory)
            : AiContactPage(
                controller: controller,
                senderId: id,
                groupId: isGroup ? conversation.id : null,
              ),
      ),
    );
  }

  final richRuns = isGroup ? <String>{} : richReplyRuns(timelineMessages);
  final watch = conversation.executionWatch;
  // “已处理”是整轮执行中的累计耗时，不是某个工具的完成状态。
  // 出现思考或工具调用后整轮只显示一次；工具结束后若仍在思考，继续计时。
  // 普通文字回复不单独显示；整轮结束由保存的处理摘要展示“用时”。
  final showElapsed =
      conversation.isTask &&
      watch != null &&
      !watch.isRunning &&
      (conversation.runState == ChatRunState.failed ||
          conversation.runState == ChatRunState.interrupted) &&
      !timelineMessages.any(
        (message) =>
            message.runId == conversation.activeRunId &&
            message.taskSummary != null,
      );
  final reasoningIds = {
    for (final message in timelineMessages)
      if (message.isReasoning) message.id,
  };
  final hiddenIds = {
    for (final message in timelineMessages)
      if (conversation.isTask && message.taskSummary != null)
        for (final id in message.taskSummary!.intermediateMessageIds)
          if (reasoningIds.contains(id) || !richRuns.contains(message.runId))
            id,
  };
  final visibleMessages = timelineMessages
      .where(
        (message) =>
            !(conversation.isPersonalChat && message.isReasoning) &&
            !(message.isReasoning &&
                message.runId == conversation.activeRunId &&
                (conversation.runState == ChatRunState.running ||
                    conversation.runState == ChatRunState.stopping)) &&
            !(message.isSystem && message.text == '私密交互消息已更新') &&
            (message.canView(MessageSender.localUser.id)) &&
            (!hiddenIds.contains(message.id) ||
                message.id == conversation.searchMessageId),
      )
      .toList();
  final firstMessageByRun = {
    for (final message in visibleMessages.reversed)
      if (message.role == AgentMessageRole.assistant && message.runId != null)
        message.runId!: message.id,
  };
  final messagePositions = {
    for (final (index, message) in visibleMessages.indexed) message.id: index,
  };
  final headersByMessage = <String, List<ChatTimelineEntry>>{};
  final headersAfterMessage = <String, List<ChatTimelineEntry>>{};
  final followingHeadersByMessage = <String, List<ChatTimelineEntry>>{};
  final toolsByMessage = <String, List<ChatTimelineEntry>>{};
  final followingToolsByMessage = <String, List<ChatTimelineEntry>>{};
  final messagesById = {
    for (final message in timelineMessages) message.id: message,
  };
  List<ChatTimelineEntry> activitiesAfter(String messageId, String runId) {
    final anchor = messagesById[messageId];
    final target =
        anchor?.role == AgentMessageRole.assistant && anchor!.runId != runId
        ? followingToolsByMessage
        : toolsByMessage;
    return target.putIfAbsent(messageId, () => []);
  }

  // Completed summaries render their saved activities; keep the source records.
  final summarizedRuns = {
    for (final message in timelineMessages)
      if (message.taskSummary != null) message.runId,
  };
  final members = controller.groupRuns.toList();
  final stepSources = !isGroup && members.isEmpty
      ? [conversation]
      : members.where((_) => !isGroup);
  final liveSteps = [
    for (final source in stepSources)
      for (final (ordinal, entry) in source.liveToolSteps.indexed)
        if (conversation.isTask &&
            !summarizedRuns.contains(entry.runId) &&
            source.runState != ChatRunState.running &&
            source.runState != ChatRunState.stopping)
          (
            ordinal: ordinal,
            afterMessageId: entry.afterMessageId,
            step: entry.step,
            runId: entry.runId,
            senderName: identical(source, conversation)
                ? null
                : source.replyingSenderName,
          ),
  ];
  final firstToolAnchorByRun = <String, String>{};
  for (final entry in liveSteps) {
    final position = messagePositions[entry.afterMessageId];
    if (position == null) continue;
    final previous = firstToolAnchorByRun[entry.runId];
    if (previous == null || position < messagePositions[previous]!) {
      firstToolAnchorByRun[entry.runId] = entry.afterMessageId;
    }
  }
  void placeRunHeader(ChatTimelineEntry header, String runId, String anchorId) {
    final firstMessage = firstMessageByRun[runId];
    final firstToolAnchor = firstToolAnchorByRun[runId];
    final toolsComeFirst =
        firstToolAnchor != null &&
        (firstMessage == null ||
            messagePositions[firstToolAnchor]! <
                messagePositions[firstMessage]!);
    if (!toolsComeFirst && firstMessage != null) {
      headersByMessage.putIfAbsent(firstMessage, () => []).add(header);
      return;
    }
    final afterId = toolsComeFirst ? firstToolAnchor : anchorId;
    final anchor = messagesById[afterId];
    final target =
        anchor?.role == AgentMessageRole.assistant && anchor!.runId != runId
        ? followingHeadersByMessage
        : headersAfterMessage;
    // Run headings are a separate slot, always preceding their tool records.
    // 标题位于本轮第一个思考或工具之前，不能随后续回调挪到工具下面。
    final headers = target.putIfAbsent(afterId, () => []);
    headers.add(header);
  }

  final memberSources = {
    for (final member in members.where((_) => !isGroup))
      member.activeRunId: webSourcesFromSteps(
        member.liveToolSteps.map((entry) => entry.step),
      ),
  };
  final liveSources = webSourcesFromSteps(liveSteps.map((entry) => entry.step));
  final groups = toolActivityGroups([
    for (final entry in liveSteps)
      const {'askUser', 'runTask'}.contains(entry.step.toolName)
          ? null
          : '${entry.runId}:${entry.afterMessageId}:${entry.step.toolName}',
  ]);
  final activeRunIds = {
    if ((conversation.runState == ChatRunState.running ||
            conversation.runState == ChatRunState.stopping) &&
        conversation.activeRunId != null)
      conversation.activeRunId!,
    for (final member in members)
      if ((member.runState == ChatRunState.running ||
              member.runState == ChatRunState.stopping) &&
          member.activeRunId != null)
        member.activeRunId!,
  };
  final lastStepByRun = <String, int>{
    for (final (index, entry) in liveSteps.indexed) entry.runId: index,
  };
  final elapsedRuns = <String>{};
  final liveElapsed = showElapsed
      ? ChatTimelineEntry(
          'elapsed:${conversation.activeRunId}',
          (_) => TaskElapsed(
            key: ValueKey(conversation.activeRunId),
            watch: watch,
            restoredElapsed: conversation.restoredExecutionElapsed,
            failed: conversation.runState == ChatRunState.failed,
          ),
        )
      : null;
  var liveElapsedPlaced = false;
  if (conversation.isTask) {
    for (final entry in conversation.cancelledRunMessages.entries) {
      elapsedRuns.add(entry.key);
      placeRunHeader(
        ChatTimelineEntry(
          'run-elapsed:${entry.key}',
          (_) => StoppedTaskElapsed(
            elapsed: conversation.unfinishedRunElapsed[entry.key]!,
            cancelled: true,
          ),
        ),
        entry.key,
        entry.value,
      );
    }
  }
  for (final group in groups) {
    final entry = liveSteps[group.start];
    final latest = liveSteps[group.end - 1];
    final storageId = 'tool:${entry.runId}:${entry.ordinal}';
    final runElapsed = conversation.unfinishedRunElapsed[entry.runId];
    if (liveElapsed != null &&
        !liveElapsedPlaced &&
        entry.runId == conversation.activeRunId) {
      placeRunHeader(liveElapsed, entry.runId, entry.afterMessageId);
      liveElapsedPlaced = true;
    }
    if (conversation.isTask &&
        runElapsed != null &&
        elapsedRuns.add(entry.runId) &&
        (entry.runId != conversation.activeRunId || !showElapsed)) {
      placeRunHeader(
        ChatTimelineEntry(
          'run-elapsed:${entry.runId}',
          (_) => StoppedTaskElapsed(elapsed: runElapsed),
        ),
        entry.runId,
        entry.afterMessageId,
      );
    }
    // Task cards occupy a message slot rather than the preceding reply's body.
    (entry.step.toolName == 'runTask'
            ? followingToolsByMessage.putIfAbsent(
                entry.afterMessageId,
                () => [],
              )
            : activitiesAfter(entry.afterMessageId, entry.runId))
        .add(
          ChatTimelineEntry(
            storageId,
            (_) =>
                entry.step.toolName == 'askUser' || group.end - group.start == 1
                ? TimelineToolActivity(
                    storageId: storageId,
                    step: entry.step,
                    senderName: entry.senderName,
                    chatBubbles: chatBubbles,
                    isGroup: isGroup,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                    child: ToolActivityGroup(
                      key: ValueKey(storageId),
                      storageId: storageId,
                      toolName: entry.step.toolName,
                      active:
                          activeRunIds.contains(entry.runId) &&
                          latest.step.status == AgentStepStatus.running &&
                          lastStepByRun[entry.runId] == group.end - 1,
                      activeLabel: _activeToolActivityTitle(
                        latest.step,
                        latest.senderName,
                      ),
                      startedAt: latest.step.startedAt,
                      finishedAt: latest.step.finishedAt,
                      activeResultJson: latest.step.resultJson,
                      fileResults:
                          entry.step.toolName == 'executeAndroidScript' ||
                              entry.step.toolName == 'runSkill'
                          ? [
                              for (var i = group.start; i < group.end; i++)
                                liveSteps[i].step.resultJson,
                            ]
                          : const [],
                      statuses: [
                        for (var i = group.start; i < group.end; i++)
                          liveSteps[i].step.status,
                      ],
                      children: [
                        for (var i = group.start; i < group.end; i++)
                          TimelineToolActivity(
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
  if (liveElapsed != null && !liveElapsedPlaced) {
    final firstRunMessage = visibleMessages.indexWhere(
      (message) => message.runId == conversation.activeRunId,
    );
    final anchor = firstRunMessage > 0
        ? visibleMessages[firstRunMessage - 1]
        : firstRunMessage == 0
        ? visibleMessages.first
        : visibleMessages.last;
    placeRunHeader(liveElapsed, conversation.activeRunId!, anchor.id);
  }
  final end = beforeMessageId == null
      ? visibleMessages.length
      : visibleMessages.indexWhere((message) => message.id == beforeMessageId);
  final replyParts = chatBubbles
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
                GroupMentionText(
                  text: conversation.creationMessage!,
                  members: noticeNameIds,
                  bareNames: true,
                  textAlign: TextAlign.center,
                  onOpen: (id) => openNoticeMember(context, id),
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
          (chatBubbles || message.role != AgentMessageRole.assistant) &&
          (replyParts[message.id]?.first ?? true) &&
          message.createdAt.difference(visibleMessages[index - 1].createdAt) >
              const Duration(minutes: 30))
        ChatTimelineEntry(
          'time:${message.id}',
          (context) => Padding(
            padding: EdgeInsets.fromLTRB(18, 24, 18, chatBubbles ? 6 : 12),
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
      if (message.id != beforeMessageId) ...?headersByMessage[message.id],
      if (conversation.isTask && message.id != beforeMessageId)
        ...taskMessageEntries(
          message.taskSummary,
          messageId: message.id,
          chatBubbles: chatBubbles,
          isGroup: isGroup,
        ),
      if (message.id != beforeMessageId)
        ChatTimelineEntry(
          message.id,
          (context) {
            if (message.isSystem) {
              if (message.messageMetadata?.participation['_taskSource'] !=
                  null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  child: TaskSourceNotice(
                    controller: controller,
                    message: message,
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                child: RecalledMessageNotice(
                  message: message,
                  onEdit: onReeditRecalled,
                  onOpenSource: onOpenQuote,
                  onOpenLink: (href) =>
                      openMiniappLink(context, Uri.parse(href)),
                  memberNames: isGroup ? noticeNameIds : const {},
                  onOpenMember: (id) => openNoticeMember(context, id),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            final content = MessageItem(
              showTaskEntries: false,
              excludedActivityMessageId: conversation.searchMessageId,
              key: ValueKey(message.id),
              message: message,
              replyPart: replyParts[message.id],
              trailingActivities:
                  !isGroup &&
                      message.role == AgentMessageRole.assistant &&
                      !message.isReasoning &&
                      message.id != beforeMessageId &&
                      (headersAfterMessage.containsKey(message.id) ||
                          toolsByMessage.containsKey(message.id))
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in [
                          ...?headersAfterMessage[message.id],
                          ...?toolsByMessage[message.id],
                        ])
                          KeyedSubtree(
                            key: ValueKey(entry.id),
                            child: entry.builder(context),
                          ),
                      ],
                    )
                  : null,
              mentionMembers: mentionMembers,
              interactiveMembers: interactiveMembers,
              htmlView: message.htmlGame == null
                  ? null
                  : HtmlView(
                      card: message.htmlGame!,
                      surfaceId: singleMessage == null ? 'chat' : 'pinned',
                      messageId: message.id,
                      conversationId: conversation.id,
                      store: controller.htmlStore,
                      onOpenProfile: (senderId) async {
                        if (!context.mounted) return;
                        await openProfileRoute(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                senderId == MessageSender.localUser.id
                                ? PersonalInfoPage(memory: controller.memory)
                                : AiContactPage(
                                    controller: controller,
                                    senderId: senderId,
                                    groupId: conversation.id,
                                  ),
                          ),
                        );
                      },
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
              groupBubble: chatBubbles,
              showSenderAvatar: isGroup,
              onQuote:
                  !controller.isStreamingMessage(message.id) &&
                      (message.text.isNotEmpty ||
                          message.images.isNotEmpty ||
                          message.files.isNotEmpty ||
                          message.interactive != null ||
                          message.htmlGame != null)
                  ? onQuote
                  : null,
              onOpenQuote: onOpenQuote,
              onOpenMember: (id) => openNoticeMember(context, id),
              onQuickReply:
                  !message.isSystem &&
                      !message.isReasoning &&
                      message.interactive?.systemPresentation != true &&
                      (message.role == AgentMessageRole.assistant ||
                          message.senderId == MessageSender.localUser.id)
                  ? onQuickReply
                  : null,
              onRetry:
                  onRetry != null &&
                      (message.isFailure ||
                          controller.canOfferFailedRetry(message))
                  ? onRetry
                  : null,
              availableSources:
                  memberSources[message.runId] ??
                  (message.runId != null &&
                          message.runId == conversation.activeRunId
                      ? liveSources
                      : const {}),
              onRecall:
                  (conversation.kind == ConversationKind.group ||
                          conversation.isPersonalChat) &&
                      message.senderId == MessageSender.localUser.id
                  ? onRecall
                  : null,
              onEdit: allowEditing && conversation.isTask ? onEdit : null,
              streaming:
                  controller.isStreamingMessage(message.id) ||
                  (members.isEmpty &&
                      controller.isBusy &&
                      message.runId ==
                          controller.activeConversation.activeRunId),
            );
            final messageBody =
                chatBubbles &&
                    message.role == AgentMessageRole.assistant &&
                    message.sender != null &&
                    message.interactive?.systemPresentation != true
                ? GroupMessageHeading(
                    trailingInset: message.hasRestrictedAudience
                        ? GroupMessageHeading.restrictedRightInset
                        : GroupMessageHeading.rightInset,
                    groupId: isGroup ? conversation.id : null,
                    showName: isGroup,
                    showAvatar: isGroup,
                    sender:
                        conversation.noticeMembers[message.senderId] ??
                        message.sender!,
                    onMention: !isGroup || onMention == null
                        ? null
                        : () => onMention(message.sender!),
                    onOpenProfile: () => openProfileRoute(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiContactPage(
                          controller: controller,
                          senderId: message.sender!.id,
                          groupId: isGroup ? conversation.id : null,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
            final item = chatBubbles
                ? ChatMessageSpacing(child: pagedBody)
                : pagedBody;
            // Keep the HTML subtree mounted when message highlighting ends.
            if (message.id != highlightedMessageId &&
                message.htmlGame == null) {
              return item;
            }
            return TweenAnimationBuilder<double>(
              tween: Tween(
                begin: message.id == highlightedMessageId ? .28 : 0,
                end: 0,
              ),
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
          },
          preserveState:
              message.htmlGame != null || message.interactive != null,
        ),
      if (!isGroup &&
          message.id != beforeMessageId &&
          (message.role != AgentMessageRole.assistant ||
              message.isReasoning ||
              message.isSystem)) ...[
        ...?headersAfterMessage[message.id],
        ...?toolsByMessage[message.id],
      ],
      if (!isGroup && message.id != beforeMessageId) ...[
        ...?followingHeadersByMessage[message.id],
        ...?followingToolsByMessage[message.id],
      ],
    ],
  ];
}

Map<String, String> chatSummaryOwners(ChatController controller) {
  final richRuns = richReplyRuns(controller.visibleMessages);
  final reasoningIds = {
    for (final message in controller.visibleMessages)
      if (message.isReasoning) message.id,
  };
  return {
    for (final message in controller.visibleMessages)
      'time:${message.id}': message.id,
    for (final message in controller.visibleMessages)
      if (controller.activeConversation.isTask &&
          message.taskSummary != null) ...{
        'elapsed:${message.runId}': message.id,
        for (final id in message.taskSummary!.intermediateMessageIds)
          if (id != controller.activeConversation.searchMessageId &&
              (reasoningIds.contains(id) || !richRuns.contains(message.runId)))
            id: message.id,
        for (var i = 0; i < message.taskSummary!.activities.length; i++)
          'tool:${message.runId}:$i': message.id,
        for (var i = 0; i < message.taskSummary!.activities.length; i++)
          'task-entry:${message.id}:$i': message.id,
        if (message.runId == controller.activeConversation.activeRunId)
          'progress:${controller.activeConversation.id}': message.id,
      },
  };
}

String _activeToolActivityTitle(AgentStep step, String? senderName) =>
    '${senderName == null ? '' : '$senderName '}${step.title}';
