import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'chat_controller.dart';

class PendingMessagePanel extends StatefulWidget {
  const PendingMessagePanel({
    super.key,
    required this.controller,
    required this.onSend,
    required this.child,
  });
  final ChatController controller;
  final VoidCallback onSend;
  final Widget child;

  @override
  State<PendingMessagePanel> createState() => _PendingMessagePanelState();
}

class _PendingMessagePanelState extends State<PendingMessagePanel> {
  Object? _shownError;

  @override
  Widget build(BuildContext context) {
    final queue = widget.controller.pendingMessageQueue;
    if (queue.error != null && !identical(_shownError, queue.error)) {
      _shownError = queue.error;
      final error = queue.error!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
        }
      });
    }
    if (queue.messages.isEmpty) return widget.child;
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${queue.paused ? '待发送（已暂停）' : '待发送'} · ${queue.messages.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (queue.busy)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: widget.onSend,
                          child: Text(widget.controller.isBusy ? '立即发送' : '发送'),
                        ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          ((MediaQuery.sizeOf(context).height -
                                      MediaQuery.viewInsetsOf(context).bottom) *
                                  .2)
                              .clamp(48.0, 144.0),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: queue.messages.length,
                      itemBuilder: (context, index) {
                        final message = queue.messages[index];
                        final preview = [
                          if (message.text.isNotEmpty) message.text,
                          if (message.images.isNotEmpty)
                            '${message.images.length} 张图片',
                          ...message.files.map((file) => file.name),
                          if (message.quote != null)
                            '引用：${message.quote!.text}',
                        ].join(' · ');
                        return Row(
                          key: ValueKey(message.id),
                          children: [
                            Expanded(
                              child: Text(
                                preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '移除待发送消息',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: queue.busy
                                  ? null
                                  : () async {
                                      try {
                                        await widget.controller
                                            .removePendingMessage(message.id);
                                      } on Object catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showGlassSnackBar(
                                            SnackBar(
                                              content: Text(
                                                errorMessage(error),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
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
        widget.child,
      ],
    );
  }
}
