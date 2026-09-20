import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../storage/attachment_search.dart';
import '../../domain/message_image.dart';
import 'file_attachments.dart';
import 'image_attachments.dart';

class SearchAttachmentTile extends StatelessWidget {
  const SearchAttachmentTile({
    super.key,
    required this.result,
    this.gallery = const [],
    this.compact = false,
    this.onOpen,
  });
  final AttachmentSearchResult result;
  final VoidCallback? onOpen;
  final List<MessageImage> gallery;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: compact ? 0 : 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        result.image != null
            ? LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.centerLeft,
                  child: ImageAttachment(
                    image: result.image!,
                    sourceMessageId: result.messageId,
                    gallery: gallery,
                    size: math.min(constraints.maxWidth, 144),
                    borderRadius: 18,
                    onOpen: onOpen,
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: compact ? math.min(constraints.maxWidth, 144) : 84,
                  child: FileAttachmentCard(
                    file: result.file!,
                    onOpen: onOpen,
                    vertical: compact,
                  ),
                ),
              ),
        if (result.matchText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              result.matchText!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    ),
  );
}
