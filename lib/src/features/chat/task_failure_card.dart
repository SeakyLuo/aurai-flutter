import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';

import '../../app/global_ui.dart';
import 'conversation_menu_icon.dart';
import 'glass_surface.dart';
import 'task_failure_icon.dart';
import 'task_playback_icon.dart';
import 'question_icon.dart';
import 'interactive_message_button.dart';
import '../../app/notice_details_sheet.dart';

class TaskFailureCard extends StatelessWidget {
  const TaskFailureCard({
    super.key,
    required this.onRetry,
    required this.error,
    this.actionLabel = '重试',
    this.continuing = false,
    this.busy = false,
    this.paused,
    this.enabled = true,
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 20),
  });
  final bool? paused;
  final bool enabled;
  final String error;
  final String actionLabel;
  final bool continuing;
  final bool busy;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  Future<void> _copyError(BuildContext context) async {
    final copied = await runUiAction(
      context,
      () => Clipboard.setData(ClipboardData(text: error)),
    );
    if (copied && context.mounted) {
      ScaffoldMessenger.of(context).showToast(
        const SnackBar(content: Text('已复制报错')),
        kind: ToastKind.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Container(
      padding: paused == null
          ? const EdgeInsets.fromLTRB(16, 6, 8, 16)
          : const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: GlobalUI.controlBackground(Theme.of(context)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xff3a3a3a)
              : const Color(0xffe6e6e6),
        ),
      ),
      child: paused == null
          ? _errorContent(context)
          : Row(
              children: [
                const TaskFailureIcon(size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Transform.scale(
                  scale: 0.85,
                  alignment: Alignment.centerRight,
                  transformHitTests: false,
                  child: RoundAction(
                    label: actionLabel,
                    icon: Icons.refresh_rounded,
                    iconWidget: paused == null
                        ? ConversationMenuIcon(
                            type: ConversationMenuIconType.retry,
                            color: enabled
                                ? GlobalUI.onPrimary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          )
                        : TaskPlaybackIcon(
                            paused: paused!,
                            color: enabled
                                ? GlobalUI.onPrimary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                    primary: true,
                    compact: true,
                    inkResponse: false,
                    onPressed: enabled ? onRetry : null,
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _errorContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const TaskFailureIcon(size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '回复出错',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            RoundAction(
              label: '复制报错',
              icon: Icons.copy_rounded,
              iconWidget: ConversationMenuIcon(
                type: ConversationMenuIconType.copy,
                color: colors.onSurfaceVariant,
              ),
              onPressed: () => _copyError(context),
            ),
            RoundAction(
              label: busy ? '正在继续' : actionLabel,
              icon: Icons.refresh_rounded,
              iconWidget: busy
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.65,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : continuing
                  ? QuestionIcon(
                      type: QuestionIconType.play,
                      color: enabled
                          ? colors.onSurfaceVariant
                          : colors.onSurfaceVariant.withValues(alpha: .3),
                    )
                  : ConversationMenuIcon(
                      type: ConversationMenuIconType.retry,
                      color: enabled
                          ? colors.onSurfaceVariant
                          : colors.onSurfaceVariant.withValues(alpha: .3),
                    ),
              onPressed: enabled && !busy ? onRetry : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = DefaultTextStyle.of(context).style.merge(
                TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: colors.onSurfaceVariant,
                ),
              );
              final painter = TextPainter(
                text: TextSpan(text: error, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                locale: Localizations.localeOf(context),
                maxLines: 4,
                ellipsis: '…',
              )..layout(maxWidth: constraints.maxWidth);
              final overflow = painter.didExceedMaxLines;
              painter.dispose();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    error,
                    style: style,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (overflow) ...[
                    const SizedBox(height: 12),
                    InteractiveMessageButton(
                      button: const {
                        'label': '查看详情',
                        'icon': 'none',
                        'showArrow': true,
                      },
                      busy: false,
                      locked: false,
                      onPressed: () => showNoticeDetailsSheet(
                        context,
                        text: TextSpan(text: error),
                        style: style,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
