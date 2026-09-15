import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import '../../domain/message_summary.dart';
import 'message_preview_text.dart';
import 'html_message_preview.dart';
import 'message_preview_page.dart';
import 'settings_appearance.dart';

class MessageForwardPreview extends StatelessWidget {
  const MessageForwardPreview({
    super.key,
    required this.message,
    this.enabled = true,
    this.fitAvailableHeight = false,
  });
  final AgentMessage message;
  final bool enabled;
  final bool fitAvailableHeight;

  @override
  Widget build(BuildContext context) => Material(
    color: dialogControlColor(context),
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: !enabled
          ? null
          : () {
              FocusScope.of(context).unfocus();
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => MessagePreviewPage(message: message),
                ),
              );
            },
      child: message.htmlGame != null
          ? HtmlMessagePreview(
              title: message.htmlGame!.title,
              preview: message.htmlGame!.preview,
              fitAvailableHeight: fitAvailableHeight,
            )
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: MessagePreviewText(
                      text: MessageSummary.fromMessage(message),
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '详情',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}
