part of 'chat_page.dart';

extension _ChatProgress on _ChatPageState {
  Widget _buildProgress(ChatController controller) =>
      controller.groupRuns.isNotEmpty ||
          (controller.activeConversation.kind == ConversationKind.group &&
              controller.isBusy)
      ? const SizedBox.shrink()
      : ExecutionProgress(
          hideThinking:
              controller.activeConversation.kind == ConversationKind.group,
          state: controller.isBusy && controller.runState == ChatRunState.idle
              ? ChatRunState.running
              : controller.runState,
          steps: controller.steps,
          errorDetail: controller.activeConversation.errorDetail,
          needsConfiguration: controller.needsConfiguration,
          hasPendingGoal: !controller.isBusy && controller.pendingGoal != null,
          replying: controller.hasStreamingMessages,
          senderName: controller.activeConversation.replyingSenderName,
          reconnectAttempt: controller.activeConversation.reconnectAttempt,
          onContinue: _continuePending,
          onRetry: _continuePending,
          accessibilityRequestPending: controller.accessibilityRequestPending,
          onBatterySettings: _openBatterySettings,
        );
}
