import 'package:flutter/material.dart';

import '../../storage/attachment_search.dart';
import 'attachment_action_icon.dart';
import 'image_attachments.dart';

class SearchFileResultTile extends StatelessWidget {
  const SearchFileResultTile({
    super.key,
    required this.result,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final AttachmentSearchResult result;
  final InlineSpan title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox.square(
                  dimension: 56,
                  child: result.image != null
                      ? ImageAttachment(
                          image: result.image!,
                          gallery: [result.image!],
                          size: 56,
                          borderRadius: 11,
                        )
                      : const Center(
                          child: AttachmentActionIcon(
                            type: AttachmentActionIconType.file,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: colors.onSurface,
                      ),
                    ),
                    if (result.messageExcerpt.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text.rich(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
