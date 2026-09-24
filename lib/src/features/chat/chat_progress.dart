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

  Future<void> _retryFailedMessage(AgentMessage message) =>
      _retryFailed(message.runId);
}
