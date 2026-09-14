import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import 'unavailable_image.dart';

class MessageForwardPreview extends StatelessWidget {
  const MessageForwardPreview({super.key, required this.message});
  final AgentMessage message;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (message.text.isNotEmpty)
        Text(message.text, maxLines: 6, overflow: TextOverflow.ellipsis),
      if (message.images.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final image in message.images)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(image.path),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    cacheWidth: (64 * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    errorBuilder: (_, _, _) => const SizedBox.square(
                      dimension: 64,
                      child: UnavailableImage(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      for (final file in message.files)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '[文件] ${file.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
  );
}
