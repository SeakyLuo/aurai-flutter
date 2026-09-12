part of 'chat_page.dart';

extension _ChatSessionActions on _ChatPageState {
  void _openConversations() {
    if (_editing != null) return;
    if (_imageOperationPending()) return;
    _focusNode.unfocus();
    _scaffoldKey.currentState!.openDrawer();
  }

  void _scheduleMarkRead() {
    final conversation = widget.controller.activeConversation;
    if (_markReadScheduled ||
        conversation.runState != ChatRunState.idle ||
        conversation.activeRunId == null ||
        conversation.pendingGoal != null ||
        conversation.seenRunId == conversation.activeRunId)
      return;
    _markReadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted ||
            !ModalRoute.of(context)!.isCurrent ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed ||
            _scaffoldKey.currentState!.isDrawerOpen ||
            widget.controller.activeConversation != conversation ||
            conversation.runState != ChatRunState.idle)
          return;
        await widget.controller.markActiveConversationRead();
      } on Object {
        if (mounted) _imageNotice('已读状态保存失败，请重试');
      } finally {
        _markReadScheduled = false;
      }
    });
  }

  bool _otherConversationRunning() {
    final controller = widget.controller;
    if (!controller.hasRunningTask || controller.isBusy) return false;
    _imageNotice(
      '另一个会话正在回复，完成后可发送；你可以继续浏览或编辑草稿',
      action: SnackBarAction(
        label: '查看',
        onPressed: () => _changeConversation(controller.runningConversationId),
      ),
    );
    return true;
  }

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
