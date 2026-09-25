part of 'chat_page.dart';

extension _ChatSessionActions on _ChatPageState {
  Future<void> _exitTemporaryConversation() async {
    if (_temporaryExitPending) return;
    _temporaryExitPending = true;
    try {
      _draftTimer?.cancel();
      await widget.controller.archiveTemporaryConversation(
        widget.controller.activeConversation,
      );
      if (!mounted) return;
      _updateEditing(() => _temporaryExitReady = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } on Object catch (error) {
      if (mounted) _imageNotice('临时会话归档失败，请重试：${errorMessage(error)}');
    } finally {
      _temporaryExitPending = false;
    }
  }

  Future<void> _openBatterySettings() async {
    await widget.controller.openBatterySettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('请在“电池”或“后台耗电管理”中允许 Aurai 后台运行')),
      );
    }
  }

  void _scheduleMarkRead() {
    final conversation = widget.controller.activeConversation;
    if (_markReadScheduled || _locatingInitialMessage) return;
    if (conversation.kind == ConversationKind.group) {
      if (_contentBelow ||
          conversation.searchHasLater ||
          !conversation.needsGroupReadCheckpoint)
        return;
    } else if (conversation.activeRunId == null ||
        !_hasVisibleActiveRunContent(conversation) ||
        conversation.seenRunId == conversation.activeRunId) {
      return;
    }
    _markReadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted ||
            !ModalRoute.of(context)!.isCurrent ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed ||
            _scaffoldKey.currentState!.isDrawerOpen ||
            widget.controller.activeConversation != conversation ||
            (conversation.kind == ConversationKind.group &&
                (_contentBelow || conversation.searchHasLater)) ||
            (conversation.kind != ConversationKind.group &&
                !_hasVisibleActiveRunContent(conversation)))
          return;
        await widget.controller.markActiveConversationRead();
      } on Object catch (caughtError) {
        if (mounted) _imageNotice('已读状态保存失败，请重试：${errorMessage(caughtError)}');
      } finally {
        _markReadScheduled = false;
      }
    });
  }

  bool _hasVisibleActiveRunContent(Conversation conversation) =>
      conversation.messages.any(
        (message) =>
            message.runId == conversation.activeRunId &&
            message.role == AgentMessageRole.assistant,
      ) ||
      conversation.liveToolSteps.any(
        (entry) => entry.runId == conversation.activeRunId,
      ) ||
      widget.controller.pendingQuestion?.conversationId == conversation.id;

  bool _beforeDeleteConversation() {
    if (_imageOperationPending()) return false;
    if (widget.controller.isBusy || _preparingGoal) {
      _imageNotice('请先停止当前任务，再删除会话');
      return false;
    }
    _focusNode.unfocus();
    _draftTimer?.cancel();
    return true;
  }
}
