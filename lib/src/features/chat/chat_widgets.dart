import '../../domain/message_quote.dart';
import 'message_quote_view.dart';
import '../../domain/message_file.dart';
import 'file_attachments.dart';
import 'task_failure_card.dart';
import 'reconnect_indicator.dart';
import 'package:flutter/material.dart';

import 'welcome_icon.dart';
import 'welcome_logo.dart';
import 'settings_icon.dart';
import 'sidebar_action_icon.dart';

import '../../domain/agent_models.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';
import 'message_composer.dart';
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
        padding: EdgeInsets.fromLTRB(12, contentPadding.top, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RepaintBoundary(child: WelcomeLogo()),
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
                padding: const EdgeInsets.only(bottom: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: GlassSurface(
                    radius: 24,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
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
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).colorScheme.primary
                                          .withValues(alpha: .22),
                                      Theme.of(context).colorScheme.primary
                                          .withValues(alpha: .08),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 20,
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xffc4b5fd)
                                            : const Color(0xff7959df),
                                        BlendMode.srcIn,
                                      ),
                                      child: FittedBox(child: example.$1),
                                    ),
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
                                        fontWeight: FontWeight.w500,
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
    required this.errorDetail,
    required this.hasPendingGoal,
    this.replying = false,
    this.hideThinking = false,
    this.senderName,
    this.reconnectAttempt = 0,
    this.compacting = false,
    required this.onContinue,
    required this.onRetry,
    required this.accessibilityRequestPending,
    required this.onBatterySettings,
  });

  final ChatRunState state;
  final List<AgentStep> steps;
  final bool needsConfiguration;
  final String? errorDetail;
  final bool hasPendingGoal;
  final bool replying;
  final bool hideThinking;
  final String? senderName;
  final int reconnectAttempt;
  final bool compacting;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final bool accessibilityRequestPending;
  final VoidCallback onBatterySettings;

  @override
  Widget build(BuildContext context) {
    if (hasPendingGoal &&
        !needsConfiguration &&
        (state == ChatRunState.idle || state == ChatRunState.cancelled)) {
      return TaskFailureCard(
        error: '任务待继续',
        actionLabel: '继续任务',
        paused: true,
        onRetry: onContinue,
      );
    }
    if (state == ChatRunState.interrupted) {
      return TaskFailureCard(
        onRetry: onContinue,
        error: '任务已中断',
        actionLabel: '继续任务',
      );
    }
    if (state == ChatRunState.failed) {
      return TaskFailureCard(onRetry: onRetry, error: errorDetail ?? '任务执行失败');
    }

    if (state == ChatRunState.running && compacting) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 20),
        child: ThinkingIndicator(label: '正在压缩上下文', singleLine: true),
      );
    }
    if (state == ChatRunState.running &&
        reconnectAttempt > 0 &&
        !replying &&
        !steps.any((step) => step.status == AgentStepStatus.running)) {
      return ReconnectIndicator(attempt: reconnectAttempt);
    }

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

    if (hideThinking && state == ChatRunState.running) {
      return const SizedBox.shrink();
    }

    final active =
        (state == ChatRunState.running || state == ChatRunState.stopping) &&
        !accessibilityRequestPending;
    final title = _title;
    final action = switch (state) {
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
        ],
      ),
    );
  }

  String get _title => switch (state) {
    ChatRunState.running when accessibilityRequestPending => '等待开启无障碍',
    ChatRunState.running =>
      steps.isNotEmpty && steps.last.status == AgentStepStatus.running
          ? '正在${steps.last.title}'
          : senderName == null
          ? '正在思考'
          : '$senderName 正在思考',
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
    required this.hintText,
    required this.focusNode,
    required this.enabled,
    required this.draftEnabled,
    required this.canSend,
    required this.stopping,
    required this.onSend,
    required this.onResume,
    required this.canResume,
    required this.onStop,
    required this.onAddImages,
    required this.images,
    required this.files,
    required this.onRemoveFile,
    required this.onRemoveImage,
    required this.addingImages,
    this.savingEdit = false,
    this.queueing = false,
    this.quote,
    this.onCancelQuote,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode focusNode;
  final bool enabled;
  final bool draftEnabled;
  final bool canSend;
  final bool stopping;
  final VoidCallback onSend;
  final VoidCallback onResume;
  final bool canResume;
  final VoidCallback onStop;
  final ValueChanged<BuildContext> onAddImages;
  final ValueChanged<MessageImage> onRemoveImage;
  final List<MessageImage> images;
  final List<MessageFile> files;
  final ValueChanged<MessageFile> onRemoveFile;
  final bool addingImages;
  final bool savingEdit;
  final bool queueing;
  final MessageQuote? quote;
  final VoidCallback? onCancelQuote;

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      final resume =
          canResume &&
          value.text.trim().isEmpty &&
          images.isEmpty &&
          files.isEmpty;
      return MessageComposer(
        controller: controller,
        focusNode: focusNode,
        enabled: draftEnabled,
        hintText: hintText,
        attachments:
            quote == null && images.isEmpty && files.isEmpty && !addingImages
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (quote != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                      child: MessageQuoteView(
                        quote: quote!,
                        onClose: onCancelQuote,
                      ),
                    ),
                  if (images.isNotEmpty)
                    DraftImageAttachments(
                      images: images,
                      onRemove: draftEnabled && !addingImages
                          ? onRemoveImage
                          : null,
                    ),
                  if (files.isNotEmpty)
                    FileAttachments(
                      files: files,
                      onRemove: draftEnabled && !addingImages
                          ? onRemoveFile
                          : null,
                    ),
                  if (addingImages)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                        ],
                      ),
                    ),
                ],
              ),
        leading: Builder(
          builder: (buttonContext) => RoundAction(
            label: '添加附件',
            compact: true,
            insetResponse: true,
            icon: Icons.add_rounded,
            iconWidget: Icon(
              Icons.add_rounded,
              size: 28,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
            onPressed: draftEnabled && !addingImages
                ? () => onAddImages(buttonContext)
                : null,
          ),
        ),
        action: RoundAction(
          inkResponse: false,
          label: savingEdit
              ? '正在保存'
              : enabled
              ? (addingImages
                    ? '正在处理附件'
                    : resume
                    ? '继续任务'
                    : queueing
                    ? '加入待发送'
                    : '发送')
              : stopping
              ? '正在停止'
              : '停止',
          primary: true,
          compact: true,
          iconWidget: savingEdit || (addingImages && enabled)
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onPressed: savingEdit
              ? null
              : enabled
              ? (addingImages
                    ? null
                    : resume
                    ? onResume
                    : canSend
                    ? onSend
                    : null)
              : (stopping ? null : onStop),
          icon: savingEdit
              ? Icons.arrow_upward_rounded
              : enabled
              ? (resume ? Icons.play_arrow_rounded : Icons.arrow_upward_rounded)
              : Icons.stop_rounded,
        ),
      );
    },
  );
}
