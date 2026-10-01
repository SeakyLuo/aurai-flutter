import 'package:flutter/material.dart';
import 'message_preview_text.dart';
import '../../domain/markdown_plain_text.dart';

/// A compact, non-interactive rendering; tapping the quote opens its source.
class QuoteTextPreview extends StatelessWidget {
  const QuoteTextPreview({
    super.key,
    required this.text,
    required this.style,
    this.markdown = true,
  });
  final String text;
  final bool markdown;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => MessagePreviewText(
    text: markdown ? text : memberMentionsPlainText(text),
    style: style,
    formatted: markdown,
    literal: !markdown,
  );
}
