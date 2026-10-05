import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/ui_action.dart';
import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import '../../storage/conversation_reader.dart';
import '../../storage/group_message_marks.dart';
import '../../storage/interactive_message_store.dart';
import 'chat_controller.dart';
import 'chat_timeline.dart';
import 'conversation_menu_icon.dart';
import 'header_action_menu.dart';
import 'home_navigation.dart';
import 'image_action_scope.dart';
import 'pinned_message_detail.dart';

class PinnedMessagePage extends StatefulWidget {
  const PinnedMessagePage({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.messageId,
    this.onLocate,
    this.messageBuilder,
  });
  final ChatController controller;
  final String conversationId, messageId;
  final Future<void> Function(String)? onLocate;
  final Widget Function(BuildContext, AgentMessage)? messageBuilder;
  @override
  State<PinnedMessagePage> createState() => _PinnedMessagePageState();
}

class _PinnedMessagePageState extends State<PinnedMessagePage> {
  AgentMessage? _message;
  late final StreamSubscription<String> _marks, _interactive;
  @override
  void initState() {
    super.initState();
    _marks = GroupMessageMarks.changes.stream.listen((id) {
      if (id == widget.conversationId) _checkPin();
    });
    _interactive = InteractiveMessageStore.changes.stream.listen((id) {
      if (id == widget.messageId) _load();
    });
    _load();
  }

  Future<void> _load() async {
    final success = await runUiAction(context, () async {
      final root = await getApplicationSupportDirectory();
      final messages =
          await ConversationReader(
            widget.controller.groupStore.database,
            root.path + '/message_images',
          ).messages(
            widget.conversationId,
            throughMessageId: widget.messageId,
            includeMessageId: widget.messageId,
            limit: 1,
          );
      if (!mounted) return;
      final message = messages
          .where((m) => m.id == widget.messageId)
          .firstOrNull;
      if (message == null ||
          message.isSystem ||
          !message.canView(MessageSender.localUser.id)) {
        throw StateError('消息已删除、撤回或不可见');
      }
      setState(() => _message = message);
    });
    if (!success && mounted) Navigator.pop(context);
  }

  Future<void> _checkPin() => runUiAction(context, () async {
    final pin = await GroupMessageMarks(
      widget.controller.groupStore,
    ).pinned(widget.conversationId);
    if (mounted && (pin == null || pin['id'] != widget.messageId))
      Navigator.pop(context);
  });
  Future<void> _menu(BuildContext anchor) async {
    final action = await showHeaderActionMenu(
      anchor,
      items: [
        (
          value: 'unpin',
          label: '取消置顶',
          icon: const ConversationMenuIcon(
            type: ConversationMenuIconType.removeTop,
          ),
        ),
      ],
    );
    if (!mounted || action != 'unpin') return;
    await runUiAction(
      context,
      () => GroupMessageMarks(
        widget.controller.groupStore,
      ).pin(widget.conversationId, widget.messageId, false),
    );
  }

  Future<void> _locate() async {
    if (widget.onLocate != null) {
      await widget.onLocate!(widget.messageId);
    } else {
      await openHomeConversation(
        context,
        widget.controller,
        widget.conversationId,
        messageId: widget.messageId,
      );
    }
  }

  @override
  void dispose() {
    _marks.cancel();
    _interactive.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ImageActionScope(
    controller: widget.controller,
    child: Builder(
      builder: (context) {
        final message = _message;
        return PinnedMessageDetail(
          onBack: () => Navigator.pop(context),
          onLocate: () => runUiAction(context, _locate),
          onMore: _menu,
          child: message == null
              ? const SizedBox.shrink()
              : widget.messageBuilder != null
              ? widget.messageBuilder!(context, message)
              : buildChatTimeline(
                      widget.controller,
                      singleMessage: message,
                      allowEditing: false,
                      onEdit: (_) async {},
                    )
                    .firstWhere((entry) => entry.id == message.id)
                    .builder(context),
        );
      },
    ),
  );
}
