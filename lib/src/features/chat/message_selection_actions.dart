part of 'message_item.dart';

extension _MessageSelectionActions on _MessageItemState {
  Future<SelectionMenuOptions> _loadSelectionActions() async {
    final database = ImageActionScope.of(context).groupStore.database;
    final mutable = !widget.readOnly || widget.onLocate != null;
    final (starred, mark, hasProcess, runs) = await (
      mutable
          ? StarredMessages(database).contains(message.id)
          : Future.value(false),
      mutable
          ? GroupMessageMarks(
              ImageActionScope.of(context).groupStore,
            ).status(message.id)
          : Future<GroupMessageMarkStatus?>.value(null),
      widget.groupBubble &&
              message.runId != null &&
              message.role == AgentMessageRole.assistant
          ? RunTimelineStore(database).hasProcess(message.runId!)
          : Future.value(false),
      widget.onRetry != null
          ? database.query(
              'agent_runs',
              columns: ['status'],
              where: 'id = ?',
              whereArgs: [message.runId],
            )
          : Future.value(<Map<String, Object?>>[]),
    ).wait;
    if (!mounted)
      return (starred: starred, actions: const <SelectionMenuAction>[]);
    final color = Theme.of(context).colorScheme.onSurface;
    SelectionMenuAction action(
      String label,
      Widget icon,
      MessageAction value,
    ) => (
      label: label,
      icon: icon,
      onTap: () => _openActions(directAction: value),
    );
    return (
      starred: starred,
      actions: [
        if (mark?.canPin == true)
          action(
            mark!.pinned ? '取消置顶' : '置顶消息',
            ConversationMenuIcon(
              type: mark.pinned
                  ? ConversationMenuIconType.removeTop
                  : ConversationMenuIconType.toTop,
              color: color,
            ),
            MessageAction.pin,
          ),
        if (mark != null)
          action(
            mark.favorite ? '取消标记' : '标记',
            ConversationMenuIcon(
              type: mark.favorite
                  ? ConversationMenuIconType.unmark
                  : ConversationMenuIconType.mark,
              color: color,
            ),
            MessageAction.groupFavorite,
          ),
        if (widget.onEdit != null && message.role == AgentMessageRole.user)
          action(
            '编辑消息',
            ConversationMenuIcon(
              type: ConversationMenuIconType.rename,
              color: color,
            ),
            MessageAction.edit,
          ),
        if (widget.onRecall != null)
          action(
            '撤回',
            ConversationMenuIcon(
              type: ConversationMenuIconType.recall,
              color: color,
            ),
            MessageAction.recall,
          ),
        if (hasProcess)
          action(
            '执行过程',
            SettingsIcon(type: SettingsIconType.execution, color: color),
            MessageAction.timeline,
          ),
        if (runs.isNotEmpty && runs.single['status'] == 'failed')
          action(
            classifyModelFailure(
                  ImageActionScope.of(context).activeConversation.errorDetail ??
                      '',
                ).canContinue
                ? '继续'
                : '重试',
            ConversationMenuIcon(
              type: ConversationMenuIconType.retry,
              color: color,
            ),
            MessageAction.retry,
          ),
        if (mark?.isGroup == true && message.hasRestrictedAudience)
          (
            label: '可见范围',
            icon: ConversationMenuIcon(
              type: ConversationMenuIconType.members,
              color: color,
            ),
            onTap: () => runUiAction(
              context,
              () => showMessageVisibilitySheet(
                context,
                message: message,
                database: database,
              ),
            ),
          ),
      ],
    );
  }
}
