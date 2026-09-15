import 'package:flutter/material.dart';
import 'message_preview_text.dart';

/// A compact, non-interactive rendering; tapping the quote opens its source.
class QuoteTextPreview extends StatelessWidget {
  const QuoteTextPreview({super.key, required this.text, required this.style});
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) =>
      MessagePreviewText(text: text, style: style, formatted: true);
}
