import 'package:flutter/material.dart';

import 'welcome_icon.dart';
import 'welcome_logo.dart';
import 'settings_icon.dart';
import 'sidebar_action_icon.dart';

import '../../domain/agent_models.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';
import 'thinking_indicator.dart';
import 'image_attachments.dart';
import '../../domain/message_image.dart';

class EmptyConversation extends StatelessWidget {
  const EmptyConversation({
    super.key,
    required this.onUseExample,
    required this.contentPadding,
  });

  final ValueChanged<String> onUseExample;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, contentPadding.top + 48, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WelcomeLogo(),
            const SizedBox(height: 28),
            Text(
              '有什么可以帮你？',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.35,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            for (final example in const [
              (
                WelcomeIcon(type: WelcomeIconType.network),
                '排查网络问题',
                '帮我检查并解决网络连接问题',
                '帮我检查并解决手机的网络连接问题。',
              ),
              (
                SettingsIcon(type: SettingsIconType.device),
                '了解手机状态',
                '查看电量、存储和系统信息',
                '帮我看看手机的电量、存储和系统信息。',
              ),
              (
                SidebarActionIcon(type: SidebarActionIconType.settings),
                '帮我找到设置',
                '快速进入相关系统设置',
                '帮我打开手机的电池设置。',
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x882d293b)
                      : const Color(0xbfffffff),
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => onUseExample(example.$4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .12),
                            ),
                            child: Center(
                              child: SizedBox.square(
                                dimension: 20,
                                child: FittedBox(child: example.$1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  example.$2,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  example.$3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
    this.replying = false,
    required this.onContinue,
    required this.onRetry,
    required this.accessibilityRequestPending,
    required this.onBatterySettings,
  });

  final ChatRunState state;
  final List<AgentStep> steps;
  final bool needsConfiguration;
  final bool hasPendingGoal;
  final bool replying;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final bool accessibilityRequestPending;
  final VoidCallback onBatterySettings;

  @override
  Widget build(BuildContext context) {
    if (state == ChatRunState.cancelled || accessibilityRequestPending) {
      return const SizedBox.shrink();
    }
    final streamingReply =
        state == ChatRunState.running &&
        replying &&
        !accessibilityRequestPending;
    final toolRunning =
        state == ChatRunState.running &&
        steps.isNotEmpty &&
        steps.last.status == AgentStepStatus.running &&
        !accessibilityRequestPending;
    if (streamingReply ||
        toolRunning ||
        (state == ChatRunState.idle &&
            !needsConfiguration &&
            !hasPendingGoal &&
            !accessibilityRequestPending)) {
      return const SizedBox.shrink();
    }

    final active =
        (state == ChatRunState.running || state == ChatRunState.stopping) &&
        !accessibilityRequestPending;
    final title = _title;
    final action = switch (state) {
      ChatRunState.failed => TextButton(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!streamingReply)
            Row(
              children: [
                Expanded(
                  child: ThinkingIndicator(label: title, animate: active),
                ),
                if (action != null) ...[const SizedBox(width: 12), action],
              ],
            ),
          if (state == ChatRunState.interrupted)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 12),
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
        ],
      ),
    );
  }

  String get _title => switch (state) {
    ChatRunState.running when accessibilityRequestPending => '等待开启无障碍',
    ChatRunState.running =>
      steps.isNotEmpty && steps.last.status == AgentStepStatus.running
          ? '正在${steps.last.title}'
          : '正在思考',
    ChatRunState.stopping => '正在停止',
    ChatRunState.failed => '任务未完成',
    ChatRunState.cancelled => '任务已停止',
    ChatRunState.interrupted => '任务已中断',
    ChatRunState.idle when needsConfiguration => '连接模型后继续',
    ChatRunState.idle when hasPendingGoal => '任务等待开始',
    ChatRunState.idle => '已完成',
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
    required this.onResume,
    required this.canResume,
    required this.onStop,
    required this.onAddImages,
    required this.images,
    required this.onRemoveImage,
    required this.addingImages,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool canSend;
  final bool stopping;
  final VoidCallback onSend;
  final VoidCallback onResume;
  final bool canResume;
  final VoidCallback onStop;
  final VoidCallback onAddImages;
  final ValueChanged<MessageImage> onRemoveImage;
  final List<MessageImage> images;
  final bool addingImages;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: GlassSurface(
            radius: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (images.isNotEmpty)
                    DraftImageAttachments(
                      images: images,
                      onRemove: enabled && !addingImages ? onRemoveImage : null,
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) =>
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller,
                          builder: (context, value, _) {
                            final resume =
                                canResume &&
                                value.text.trim().isEmpty &&
                                images.isEmpty;
                            final style = Theme.of(context)
                                .textTheme
                                .titleMedium!
                                .copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                );
                            const singleLinePadding = EdgeInsets.fromLTRB(
                              48,
                              10,
                              48,
                              10,
                            );
                            final textConstraints = constraints.deflate(
                              singleLinePadding,
                            );
                            final painter = TextPainter(
                              text: TextSpan(text: value.text, style: style),
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                              maxLines: 1,
                            )..layout(maxWidth: textConstraints.maxWidth);
                            final multiline =
                                value.text.contains('\n') ||
                                painter.didExceedMaxLines;
                            painter.dispose();
                            return Stack(
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                  ),
                                  child: TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    enabled: enabled,
                                    style: style,
                                    minLines: 1,
                                    maxLines: 5,
                                    textInputAction: TextInputAction.newline,
                                    decoration: InputDecoration(
                                      hintText: '回复 Aurai',
                                      hintStyle: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      contentPadding: multiline
                                          ? const EdgeInsets.fromLTRB(
                                              16,
                                              14,
                                              16,
                                              56,
                                            )
                                          : singleLinePadding,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  bottom: 0,
                                  child: RoundAction(
                                    label: '添加图片',
                                    compact: true,
                                    icon: Icons.add_rounded,
                                    onPressed: enabled && !addingImages
                                        ? onAddImages
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: RoundAction(
                                    label: enabled
                                        ? (addingImages
                                              ? '正在处理图片'
                                              : resume
                                              ? '继续任务'
                                              : '发送')
                                        : stopping
                                        ? '正在停止'
                                        : '停止',
                                    primary: true,
                                    compact: true,
                                    iconWidget: addingImages
                                        ? const SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : null,
                                    onPressed: enabled
                                        ? (addingImages
                                              ? null
                                              : resume
                                              ? onResume
                                              : canSend
                                              ? onSend
                                              : null)
                                        : (stopping ? null : onStop),
                                    icon: enabled
                                        ? (resume
                                              ? Icons.play_arrow_rounded
                                              : Icons.arrow_upward_rounded)
                                        : Icons.stop_rounded,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
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
