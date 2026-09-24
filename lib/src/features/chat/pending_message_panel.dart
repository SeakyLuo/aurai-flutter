import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';
import 'pending_queue_icon.dart';
import 'image_attachments.dart';
import 'header_action_menu.dart';
import 'conversation_menu_icon.dart';

class PendingMessagePanel extends StatefulWidget {
  const PendingMessagePanel({
    super.key,
    required this.controller,
    required this.onSend,
    required this.child,
  });
  final ChatController controller;
  final ValueChanged<String> onSend;
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: -40,
                    child: GlassSurface(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: SizedBox.expand(),
                    ),
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
                      // The composer contributes the matching 8 px below this list.
                      padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                      itemCount: queue.messages.length,
                      itemBuilder: (context, index) {
                        final message = queue.messages[index];
                        final preview = [
                          if (message.text.isNotEmpty) message.text,
                          ...message.files.map((file) => file.name),
                          if (message.quote != null)
                            '引用：${message.quote!.text}',
                        ].join(' · ');
                        return Padding(
                          key: ValueKey(message.id),
                          padding: EdgeInsets.only(
                            bottom: index == queue.messages.length - 1 ? 0 : 6,
                          ),
                          child: Row(
                            children: [
                              PendingQueueIcon(color: colors.onSurfaceVariant),
                              const SizedBox(width: 10),
                              if (message.images.isNotEmpty) ...[
                                ImageAttachment(
                                  image: message.images.first,
                                  gallery: message.images,
                                  size: 32,
                                  borderRadius: 6,
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Text(
                                  preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              Builder(
                                builder: (anchor) => IconButton(
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(40, 32),
                                    maximumSize: const Size(40, 32),
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  tooltip: '更多',
                                  icon: const Icon(
                                    Icons.more_horiz_rounded,
                                    size: 20,
                                  ),
                                  onPressed: queue.busy
                                      ? null
                                      : () => _more(anchor, message.id),
                                ),
                              ),
                            ],
                          ),
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

  Future<void> _more(BuildContext anchor, String messageId) async {
    final controller = widget.controller;
    final conversationId = controller.activeConversation.id;
    final colors = Theme.of(context).colorScheme;
    final action = await showHeaderActionMenu(
      anchor,
      items: [
        (
          value: 'send',
          label: '立刻发送',
          icon: Icon(
            Icons.arrow_upward_rounded,
            color: colors.onSurface,
            size: 21,
          ),
        ),
        (
          value: 'delete',
          label: '删除',
          icon: ConversationMenuIcon(
            type: ConversationMenuIconType.delete,
            color: colors.error,
          ),
        ),
      ],
      destructiveValues: const {'delete'},
    );
    if (!mounted ||
        action == null ||
        controller.activeConversation.id != conversationId ||
        controller.pendingMessageQueue.busy ||
        !controller.pendingMessageQueue.messages.any(
          (message) => message.id == messageId,
        ))
      return;
    if (action == 'send') {
      widget.onSend(messageId);
      return;
    }
    try {
      await controller.removePendingMessage(messageId);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    }
  }
}
