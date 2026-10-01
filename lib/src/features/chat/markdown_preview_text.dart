import '../../domain/markdown_plain_text.dart';

/// Extract visible text before the list applies its single-line ellipsis.
String markdownPreviewText(String source) => markdownCompactText(source);
