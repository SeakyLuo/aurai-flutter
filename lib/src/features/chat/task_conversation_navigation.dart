import 'package:flutter/material.dart';

import '../../app/ui_action.dart';
import 'chat_controller.dart';
import 'chat_page.dart';
import 'conversation_messages_skeleton.dart';
import 'settings_appearance.dart';

Future<void> openTaskConversation(
  BuildContext context,
  ChatController controller,
  String id, {
  required String title,
}) async {
  final sourceId = controller.activeConversation.id;
  // Cover the source route before changing the shared controller. Pushing into
  // its pane navigator would make both visible chat routes show the same task.
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => _TaskConversationPage(
        controller: controller,
        taskId: id,
        title: title,
      ),
    ),
  );
  if (context.mounted) await controller.restoreConversation(sourceId);
}

class _TaskConversationPage extends StatefulWidget {
  const _TaskConversationPage({
    required this.controller,
    required this.taskId,
    required this.title,
  });

  final ChatController controller;
  final String taskId, title;

  @override
  State<_TaskConversationPage> createState() => _TaskConversationPageState();
}

class _TaskConversationPageState extends State<_TaskConversationPage> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final loaded = await runUiAction(
      context,
      () => widget.controller.selectConversation(widget.taskId),
    );
    if (!mounted) return;
    if (!loaded) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _ready,
    // Skeletons belong to this route's initial load, not to the shared
    // controller's switching state (which also covers returning to the chat).
    child: _ready
        ? ChatPage(controller: widget.controller, stacked: true, fromTask: true)
        : Scaffold(
            extendBodyBehindAppBar: true,
            appBar: SettingsAppBar(title: widget.title, onBack: null),
            body: const ConversationMessagesSkeleton(),
          ),
  );
}
