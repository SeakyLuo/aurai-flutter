import '../../domain/message_file.dart';
import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import 'chat_viewport.dart';
import '../../domain/message_image.dart';

class MessageEditSession {
  MessageEditSession({
    required this.message,
    required this.bookmark,
    required this.sentMessageId,
    required this.followOutput,
    required this.contentBelow,
    required this.draft,
  }) : images = [...message.images],
       files = [...message.files];
  final AgentMessage message;
  final ChatScrollBookmark? bookmark;
  final String? sentMessageId;
  final bool followOutput;
  final bool contentBelow;
  final TextEditingValue draft;
  final List<MessageImage> images;
  final List<MessageFile> files;
  final List<MessageFile> addedFiles = [];
  final List<MessageImage> addedImages = [];
  bool saving = false;
  bool picking = false;
}

class MessageEditNotice extends StatelessWidget {
  const MessageEditNotice({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline_rounded, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('编辑此消息将从此处重新启动对话。', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    ),
  );
}
