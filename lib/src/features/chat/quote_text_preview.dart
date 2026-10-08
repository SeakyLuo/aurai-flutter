import 'package:flutter/material.dart';
import '../../domain/message_summary.dart';
import 'message_preview_text.dart';
import '../../domain/markdown_plain_text.dart';

/// A compact, non-interactive rendering; tapping the quote opens its source.
class QuoteTextPreview extends StatelessWidget {
  const QuoteTextPreview({
    super.key,
    required this.text,
    required this.style,
    this.markdown = true,
    this.maxLines = 2,
  });
  final String text;
  final bool markdown;
  final int maxLines;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => MessagePreviewText(
    text: markdown
        ? MessageSummary.preview(text, limit: 1024)
        : memberMentionsPlainText(MessageSummary.preview(text, limit: 1024)),
    style: style,
    formatted: markdown,
    literal: !markdown,
    maxLines: maxLines,
    textWidthBasis: TextWidthBasis.longestLine,
  );
}
