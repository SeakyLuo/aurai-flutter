import 'app_page_navigation.dart';
import 'home_navigation.dart';
import 'package:flutter/material.dart';

import 'chat_controller.dart';
import 'conversation_notification_toast.dart';

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
  OverlayEntry? _completionToast;

  void _hideCompletionToast() {
    _completionToast?.remove();
    _completionToast?.dispose();
    _completionToast = null;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.openAppPage = (args) =>
        navigateAppPage(context, widget.controller, args);
    widget.controller.completedReplies.addListener(_onCompleted);
    widget.controller.memory.notices.addListener(_onMemoryNotice);
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
    _hideCompletionToast();
    widget.controller.openAppPage = null;
    widget.controller.completedReplies.removeListener(_onCompleted);
    widget.controller.memory.notices.removeListener(_onMemoryNotice);
    widget.controller.notificationOpenRequests.removeListener(
      _openSystemNotification,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _hideCompletionToast();
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
      await openHomeConversation(context, widget.controller, id);
      await widget.controller.markActiveConversationRead();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('会话暂时无法打开，请稍后重试')));
      }
    }
  }

  void _onMemoryNotice() {
    final notice = widget.controller.memory.notices.value;
    if (notice == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
  }

  void _onCompleted() {
    final completion = widget.controller.completedReplies.value!;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    if (widget.controller.activeConversation.id == completion.conversationId)
      return;
    _hideCompletionToast();
    _completionToast = OverlayEntry(
      builder: (context) => ConversationNotificationToast(
        title: completion.title,
        reply: completion.reply,
        onDismiss: _hideCompletionToast,
        onOpen: () {
          _openConversation(completion.conversationId);
          return true;
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_completionToast!);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
