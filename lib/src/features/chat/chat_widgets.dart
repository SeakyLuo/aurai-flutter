import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';

class EmptyConversation extends StatelessWidget {
  const EmptyConversation({super.key, required this.onUseExample});

  final ValueChanged<String> onUseExample;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xffedf5ff),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 28,
              color: Color(0xff1685f8),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '有什么可以帮你？',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xff23242e),
              height: 1.35,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '从一个问题开始，或让我帮你完成手机上的任务。',
            style: TextStyle(
              color: Color(0xff737580),
              height: 1.7,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '试着这样开始',
            style: TextStyle(color: Color(0xff90919c), fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final example in const [
            (
              Icons.wifi_rounded,
              '排查网络问题',
              'ChatGPT 又报 SSL certificate error 了，帮我排查一下。',
            ),
            (Icons.phone_android_rounded, '了解手机状态', '帮我看看手机当前的网络和设备状态。'),
            (Icons.explore_outlined, '帮我找到设置', '帮我打开手机的电池设置。'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: const Color(0xfff7f7fa),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onUseExample(example.$3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          example.$1,
                          size: 20,
                          color: const Color(0xff626371),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            example.$2,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const Icon(
                          Icons.north_west_rounded,
                          size: 16,
                          color: Color(0xff9696a3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class ExecutionProgress extends StatelessWidget {
  const ExecutionProgress({
    super.key,
    required this.state,
    required this.steps,
    required this.needsConfiguration,
    required this.hasPendingGoal,
    required this.onContinue,
    required this.onRetry,
    required this.accessibilityRequestPending,
    required this.onEnableAccessibility,
    required this.onCancelAccessibility,
    required this.onBatterySettings,
  });

  final ChatRunState state;
  final List<AgentStep> steps;
  final bool needsConfiguration;
  final bool hasPendingGoal;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final bool accessibilityRequestPending;
  final VoidCallback onEnableAccessibility;
  final VoidCallback onCancelAccessibility;
  final VoidCallback onBatterySettings;

  @override
  Widget build(BuildContext context) {
    final completed = steps
        .where((step) => step.status == AgentStepStatus.completed)
        .length;
    final title = _title(completed);
    final action = switch (state) {
      ChatRunState.failed || ChatRunState.cancelled => TextButton(
        onPressed: onRetry,
        child: const Text('重试'),
      ),
      ChatRunState.interrupted => null,
      ChatRunState.idle when needsConfiguration => TextButton(
        onPressed: onContinue,
        child: const Text('连接模型'),
      ),
      ChatRunState.idle when hasPendingGoal => TextButton(
        onPressed: onContinue,
        child: const Text('继续任务'),
      ),
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      decoration: BoxDecoration(
        color: const Color(0xfff7f7fa),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe9e9f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: _leading(),
            title: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            trailing: action,
          ),
          if (state == ChatRunState.interrupted)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: onContinue,
                    child: const Text('继续任务'),
                  ),
                  TextButton(
                    onPressed: onBatterySettings,
                    child: const Text('调整后台运行'),
                  ),
                ],
              ),
            ),
          if (accessibilityRequestPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '需要无障碍权限来观察和操作其他 App。开启后返回，任务会自动继续。',
                    style: TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: onEnableAccessibility,
                        child: const Text('去开启'),
                      ),
                      TextButton(
                        onPressed: onCancelAccessibility,
                        child: const Text('暂不开启'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (steps.isNotEmpty)
            ExpansionTile(
              key: ValueKey<String>(
                state == ChatRunState.running ? 'active' : 'settled',
              ),
              initiallyExpanded: false,
              title: Text(
                '查看执行过程 · ${steps.length} 步',
                style: const TextStyle(fontSize: 12, color: Color(0xff737580)),
              ),
              children: [
                for (final step in steps)
                  ListTile(
                    dense: true,
                    leading: Icon(_stepIcon(step.status), size: 19),
                    title: Text(step.title),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _title(int completed) => switch (state) {
    ChatRunState.running =>
      steps.isEmpty
          ? '正在规划…'
          : steps.last.status == AgentStepStatus.running
          ? '正在执行 · 第 ${steps.length} 步'
          : '正在分析 · 已完成 $completed 项',
    ChatRunState.stopping => '正在停止…',
    ChatRunState.failed => '任务未完成',
    ChatRunState.cancelled => '任务已停止',
    ChatRunState.interrupted => '任务已中断',
    ChatRunState.idle when needsConfiguration => '连接模型后继续',
    ChatRunState.idle when hasPendingGoal => '任务等待开始',
    ChatRunState.idle => '已完成 $completed 个步骤',
  };

  Widget _leading() {
    if (state == ChatRunState.running || state == ChatRunState.stopping) {
      return const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }
    return Icon(
      state == ChatRunState.idle
          ? Icons.check_circle_outline_rounded
          : Icons.info_outline_rounded,
      color: const Color(0xff1685f8),
    );
  }

  static IconData _stepIcon(AgentStepStatus status) => switch (status) {
    AgentStepStatus.running => Icons.pending_rounded,
    AgentStepStatus.completed => Icons.check_circle_outline_rounded,
    AgentStepStatus.failed => Icons.error_outline_rounded,
    AgentStepStatus.cancelled => Icons.stop_circle_outlined,
  };
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.canSend,
    required this.stopping,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool canSend;
  final bool stopping;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: GlassSurface(
            radius: 34,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.5,
                        color: Color(0xff171717),
                      ),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '回复 Aurai',
                        hintStyle: TextStyle(
                          color: Color(0xff92979e),
                          fontSize: 17,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RoundAction(
                    label: enabled
                        ? '发送'
                        : stopping
                        ? '正在停止'
                        : '停止',
                    primary: true,
                    onPressed: enabled
                        ? (canSend ? onSend : null)
                        : (stopping ? null : onStop),
                    icon: enabled
                        ? Icons.arrow_upward_rounded
                        : Icons.stop_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
