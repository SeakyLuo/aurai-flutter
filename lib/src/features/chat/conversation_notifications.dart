import 'package:flutter/material.dart';

import 'chat_controller.dart';

class ConversationNotifications extends StatefulWidget {
  const ConversationNotifications({
    super.key,
    required this.controller,
    required this.child,
  });

  final ChatController controller;
  final Widget child;

  @override
  State<ConversationNotifications> createState() =>
      _ConversationNotificationsState();
}

class _ConversationNotificationsState extends State<ConversationNotifications>
    with WidgetsBindingObserver {
  bool _openingNotification = false;
  @override
  void initState() {
    super.initState();
    widget.controller.completedReplies.addListener(_onCompleted);
    widget.controller.notificationOpenRequests.addListener(
      _openSystemNotification,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openSystemNotification(),
    );
  }

  @override
  void dispose() {
    widget.controller.completedReplies.removeListener(_onCompleted);
    widget.controller.notificationOpenRequests.removeListener(
      _openSystemNotification,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openSystemNotification(),
      );
    }
  }

  Future<void> _openSystemNotification() async {
    if (!mounted ||
        _openingNotification ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    _openingNotification = true;
    try {
      final id = await widget.controller.takeNotificationConversation();
      if (!mounted || id == null) return;
      await _openConversation(id);
    } finally {
      _openingNotification = false;
    }
  }

  Future<void> _openConversation(String id) async {
    try {
      if (widget.controller.activeConversation.id != id) {
        await widget.controller.selectConversation(id);
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).popUntil((route) => route.isFirst && !route.willHandlePopInternally);
      await widget.controller.markActiveConversationRead();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('会话暂时无法打开，请稍后重试')));
      }
    }
  }

  void _onCompleted() {
    final completion = widget.controller.completedReplies.value!;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    if (ModalRoute.of(context)!.isCurrent &&
        widget.controller.activeConversation.id == completion.conversationId)
      return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              Icons.check_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onInverseSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“${completion.title}”已完成回复',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    completion.reply,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => _openConversation(completion.conversationId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
