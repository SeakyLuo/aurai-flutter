part of 'chat_page.dart';

extension _ChatProgress on _ChatPageState {
  void _showRunNotice(Object error) {
    if (!mounted) return;
    final controller = widget.controller;
    final message = errorMessage(error);
    final displayedInConversation =
        controller.activeConversation.kind != ConversationKind.group &&
        controller.groupRuns.isEmpty &&
        controller.runState == ChatRunState.failed &&
        controller.errorDetail == message;
    if (displayedInConversation) return;
    final stopped = controller.runState == ChatRunState.cancelled;
    ScaffoldMessenger.of(
      context,
    ).showGlassSnackBar(SnackBar(content: Text(stopped ? '任务已停止' : message)));
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
          onRetry: _continuePending,
          accessibilityRequestPending: controller.accessibilityRequestPending,
          onBatterySettings: _openBatterySettings,
        );
}
