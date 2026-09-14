part of 'chat_page.dart';

extension _ChatSessionActions on _ChatPageState {
  Future<void> _openBatterySettings() async {
    await widget.controller.openBatterySettings();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('请在“电池”或“后台耗电管理”中允许 Aurai 后台运行')));
    }
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
      } on Object catch (caughtError) {
        if (mounted) _imageNotice('已读状态保存失败，请重试：${errorMessage(caughtError)}');
      } finally {
        _markReadScheduled = false;
      }
    });
  }

  bool _otherConversationRunning() {
    final controller = widget.controller;
    if (!controller.hasRunningTask ||
        controller.isBusy ||
        controller.canStartPrivateDuringGroup)
      return false;
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
