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
import 'interactive_reference_sheet.dart';

class PinnedMessagePage extends StatefulWidget {
  const PinnedMessagePage({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.messageId,
    this.onLocate,
    this.messageBuilder,
    this.sheet = false,
    this.pinned = true,
    this.initialMessage,
    this.interactiveReference = false,
  });
  final ChatController controller;
  final String conversationId, messageId;
  final Future<void> Function(String)? onLocate;
  final Widget Function(BuildContext, AgentMessage)? messageBuilder;
  final bool sheet, pinned;
  final AgentMessage? initialMessage;
  final bool interactiveReference;
  @override
  State<PinnedMessagePage> createState() => _PinnedMessagePageState();
}

class _PinnedMessagePageState extends State<PinnedMessagePage> {
  AgentMessage? _message;
  int _request = 0;
  bool _closing = false;
  late final StreamSubscription<String> _marks, _interactive;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncMessage);
    _marks = GroupMessageMarks.changes.stream.listen((id) {
      if (widget.pinned && id == widget.conversationId) _checkPin();
    });
    _interactive = InteractiveMessageStore.changes.stream.listen((id) {
      if (id == widget.messageId) _load();
    });
    _message = widget.initialMessage;
    if (_message == null) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
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
      if (!mounted || request != _request) return;
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
    if (!success && mounted && request == _request) _close();
  }

  void _syncMessage() {
    final message = widget.controller.visibleMessages
        .where((message) => message.id == widget.messageId)
        .firstOrNull;
    if (message == null || identical(message, _message)) return;
    if (message.isSystem || !message.canView(MessageSender.localUser.id)) {
      _load();
    } else {
      setState(() => _message = message);
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    final route = ModalRoute.of(context)!;
    if (route.isCurrent) {
      Navigator.pop(context);
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  Future<void> _checkPin() => runUiAction(context, () async {
    final pin = await GroupMessageMarks(
      widget.controller.groupStore,
    ).pinned(widget.conversationId);
    if (mounted && (pin == null || pin['id'] != widget.messageId)) _close();
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
    if (widget.sheet) Navigator.pop(context);
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
    widget.controller.removeListener(_syncMessage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ImageActionScope(
    controller: widget.controller,
    child: Builder(
      builder: (context) {
        final message = _message;
        if (widget.interactiveReference && message != null) {
          return InteractiveReferenceSheet(
            controller: widget.controller,
            message: message,
          );
        }
        return PinnedMessageDetail(
          sheet: widget.sheet,
          title: widget.pinned ? '置顶详情' : '消息详情',
          onBack: () => Navigator.pop(context),
          onLocate: () => runUiAction(context, _locate),
          onMore: widget.pinned ? _menu : null,
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
