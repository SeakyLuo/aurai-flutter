import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../domain/agent_models.dart';
import 'chat_controller.dart';
import 'group_mention_text.dart';
import 'home_navigation.dart';

class TaskSourceNotice extends StatefulWidget {
  const TaskSourceNotice({
    super.key,
    required this.controller,
    required this.message,
  });

  final ChatController controller;
  final AgentMessage message;

  @override
  State<TaskSourceNotice> createState() => _TaskSourceNoticeState();
}

class _TaskSourceNoticeState extends State<TaskSourceNotice> {
  late final _sourceLink = TapGestureRecognizer()..onTap = _openSource;

  void _openSource() {
    final source =
        widget.message.messageMetadata!.participation['_taskSource'] as Map;
    runUiAction(
      context,
      () => openHomeConversation(
        context,
        widget.controller,
        source['conversationId'] as String,
        messageId: source['messageId'] as String,
        resetStack: true,
      ),
    );
  }

  @override
  void dispose() {
    _sourceLink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${widget.message.text} '),
          TextSpan(
            text: '查看来源',
            style: groupMentionStyle(context),
            recognizer: _sourceLink,
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        height: 1.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
