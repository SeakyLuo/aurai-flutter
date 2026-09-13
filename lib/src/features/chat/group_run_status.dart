import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import 'conversation.dart';
import 'thinking_indicator.dart';

class GroupRunStatus extends StatelessWidget {
  const GroupRunStatus({
    super.key,
    required this.conversation,
    required this.streaming,
  });
  final Conversation conversation;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final state = conversation.runState;
    if (state == ChatRunState.idle ||
        (state == ChatRunState.running &&
            (conversation.reconnectAttempt == 0 ||
                streaming ||
                conversation.steps.any(
                  (step) => step.status == AgentStepStatus.running,
                )))) {
      return const SizedBox.shrink();
    }
    final action = switch (state) {
      ChatRunState.stopping => '正在停止',
      ChatRunState.cancelled => '已停止',
      ChatRunState.failed => '未完成回复',
      ChatRunState.interrupted => '回复已中断',
      _ => '正在重新连接',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: ThinkingIndicator(
        label: '${conversation.replyingSenderName} $action',
        animate:
            state == ChatRunState.running || state == ChatRunState.stopping,
      ),
    );
  }
}
