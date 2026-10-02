part of 'chat_page.dart';

extension _ChatProgress on _ChatPageState {
  void _showRunNotice(Object error) {
    if (!mounted || !ModalRoute.of(context)!.isCurrent) return;
    final controller = widget.controller;
    if (controller.isRecordedRunError(error)) return;
    if (controller.runState == ChatRunState.cancelled) return;
    final message = errorMessage(error);
    final displayedInConversation =
        controller.activeConversation.kind != ConversationKind.group &&
        controller.groupRuns.isEmpty &&
        (controller.runState == ChatRunState.failed ||
            controller.runState == ChatRunState.interrupted) &&
        controller.errorDetail == message;
    if (displayedInConversation) return;
    _runNotice?.close();
    _runNotice = ScaffoldMessenger.of(
      context,
    ).showGlassSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildProgress(ChatController controller) =>
      controller.groupRuns.isNotEmpty ||
          controller.activeConversation.kind == ConversationKind.group
      ? const SizedBox.shrink()
      : ExecutionProgress(
          hideThinking:
              controller.activeConversation.kind == ConversationKind.group,
          state: controller.isBusy && controller.runState == ChatRunState.idle
              ? ChatRunState.running
              : controller.runState,
          steps: controller.steps,
          errorDetail: controller.activeConversation.errorDetail,
          needsConfiguration: controller.needsReplyConfiguration,
          hasPendingGoal: !controller.isBusy && controller.pendingGoal != null,
          replying: controller.hasStreamingMessages,
          senderName: controller.activeConversation.replyingSenderName,
          compacting: controller.activeConversation.isCompacting,
          reconnectAttempt: controller.activeConversation.reconnectAttempt,
          onContinue: _continuePending,
          onRetry: () => unawaited(_retryFailed()),
          accessibilityRequestPending: controller.accessibilityRequestPending,
          onBatterySettings: _openBatterySettings,
        );

  Future<void> _retryFailed([String? runId]) async {
    final controller = widget.controller;
    final conversationId = controller.activeConversation.id;
    if (_preparingGoal || controller.addingImages) return;
    if (controller.needsReplyConfiguration) {
      _preparingGoal = true;
      try {
        final saved = await ModelSettingsSheet.show(
          context,
          controller: controller,
          continueAfterSave: false,
        );
        if (!saved || !mounted) return;
      } finally {
        _preparingGoal = false;
      }
    }
    try {
      await controller.retryFailedRun(runId);
    } on Object catch (error) {
      if (mounted && controller.activeConversation.id == conversationId) {
        _showRunNotice(error);
      }
    }
  }

  Future<void> _retryFailedMessage(AgentMessage message) async {
    if (widget.controller.activeConversation.kind == ConversationKind.direct) {
      await _retryFailed(message.runId);
      return;
    }
    final viewport = _viewportKey.currentState;
    try {
      final controller = widget.controller;
      final conversationId = controller.activeConversation.id;
      final paused = await GroupParticipation(
        controller.groupStore.database,
      ).paused(conversationId);
      if (!mounted || controller.activeConversation.id != conversationId)
        return;
      var resumeAutoReply = false;
      if (paused.contains(message.senderId)) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (context) => AppPromptDialog(
            title: '该成员已暂停接话',
            description: '仅重试这次回复，还是同时恢复后续自动接话？',
            actions: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                DialogActionButton(
                  text: '仅重试本次',
                  onPressed: () => Navigator.pop(context, false),
                ),
                const SizedBox(height: 10),
                DialogActionButton(
                  text: '恢复接话并重试',
                  role: DialogActionRole.secondary,
                  onPressed: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 10),
                DialogActionButton(
                  text: '取消',
                  role: DialogActionRole.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
        if (!mounted ||
            controller.activeConversation.id != conversationId ||
            choice == null)
          return;
        resumeAutoReply = choice;
      }
      await widget.controller.retryFailedMessage(
        message,
        resumeAutoReply: resumeAutoReply,
        beforeRemoval: () async => viewport?.animateRemoval(message.id),
      );
    } on Object catch (error) {
      _showRunNotice(error);
    } finally {
      viewport?.finishRemoval(message.id);
    }
  }
}
