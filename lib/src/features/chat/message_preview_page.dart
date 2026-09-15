import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../domain/agent_models.dart';
import 'cjk_strong_syntax.dart';
import 'file_attachments.dart';
import 'image_attachments.dart';
import 'settings_appearance.dart';

class MessagePreviewPage extends StatelessWidget {
  const MessagePreviewPage({super.key, required this.message});
  final AgentMessage message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(title: '预览消息', onBack: () => Navigator.pop(context)),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          if (message.htmlGame case final html?) ...[
            Text(html.title, style: Theme.of(context).textTheme.titleMedium),
            if (html.preview case final preview?) ...[
              const SizedBox(height: 12),
              Image.memory(preview),
            ],
          ],
          if (message.text.isNotEmpty)
            MarkdownBody(
              data: message.text,
              selectable: true,
              inlineSyntaxes: [CjkStrongSyntax()],
            ),
          if (message.interactive case final card?) ...[
            Text(card.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            MarkdownBody(
              data: card.body,
              selectable: true,
              inlineSyntaxes: [CjkStrongSyntax()],
            ),
          ],
          if (message.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final image in message.images)
                  ImageAttachment(
                    image: image,
                    gallery: message.images,
                    size: 160,
                  ),
              ],
            ),
          ],
          for (final file in message.files)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FileAttachmentCard(file: file),
            ),
        ],
      ),
    ),
  );
}
