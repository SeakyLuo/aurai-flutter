import 'dart:typed_data';
import 'html_message_preview.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/message_image.dart';
import '../../domain/message_file.dart';
import '../../domain/message_summary.dart';
import 'image_attachments.dart';
import 'message_preview_text.dart';
import 'unavailable_image.dart';

/// Content-only preview; the caller owns sender, timestamp and navigation.
class MessageContentPreview extends StatelessWidget {
  const MessageContentPreview({
    super.key,
    required this.text,
    this.images = const [],
    this.files = const [],
    this.htmlTitle,
    this.htmlPreview,
    this.interactiveTitle,
    this.maxLines = 3,
    this.query = '',
    this.style,
    this.gallery,
    this.sourceMessageId,
    this.maxImages = 3,
  });
  final Uint8List? htmlPreview;
  final String text, query;
  final String? htmlTitle, interactiveTitle, sourceMessageId;
  final List<MessageImage> images;
  final List<MessageFile> files;
  final List<MessageImage>? gallery;
  final int? maxLines;
  final int maxImages;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final body = MessageSummary.content(
      text: text,
      htmlTitle: htmlTitle,
      interactiveTitle: interactiveTitle,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (htmlTitle != null)
          HtmlMessagePreview(
            title: htmlTitle!,
            preview: htmlPreview,
            query: query,
          )
        else if (body.isNotEmpty)
          MessagePreviewText(
            text: body,
            maxLines: maxLines,
            query: query,
            snippet: true,
            style: style,
          ),
        if (images.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: body.isEmpty ? 0 : 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final image in images.take(maxImages))
                  if (gallery != null)
                    ImageAttachment(
                      image: image,
                      gallery: gallery!,
                      sourceMessageId: sourceMessageId,
                      size: 64,
                      borderRadius: 10,
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(image.path),
                        width: 64,
                        height: 64,
                        cacheWidth:
                            (64 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.square(
                          dimension: 64,
                          child: UnavailableImage(),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        for (final file in files)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: file.isHtml
                ? HtmlMessagePreview(
                    title: MessageSummary.htmlFileTitle(file.name),
                    query: query,
                  )
                : MessagePreviewText(
                    text: MessageSummary.attachment(
                      kind: 'file',
                      mimeType: file.mimeType,
                      name: file.name,
                    ),
                    literal: true,
                    maxLines: 2,
                    query: query,
                    style: style,
                  ),
          ),
      ],
    );
  }
}
