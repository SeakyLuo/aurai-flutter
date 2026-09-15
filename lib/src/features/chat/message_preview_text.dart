import 'package:flutter/material.dart';
import 'markdown_preview_text.dart';
import 'package:markdown/markdown.dart' as md;
import 'cjk_strong_syntax.dart';

/// Passive text rendering shared by summaries, forwarding and search results.
class MessagePreviewText extends StatelessWidget {
  const MessagePreviewText({
    super.key,
    required this.text,
    this.maxLines = 2,
    this.style,
    this.query = '',
    this.snippet = false,
    this.prefix = const [],
    this.literal = false,
    this.formatted = false,
  });
  final String text, query;
  final int? maxLines;
  final TextStyle? style;
  final bool snippet, literal, formatted;
  final List<InlineSpan> prefix;

  static TextSpan span(
    BuildContext context,
    String source, {
    String query = '',
    bool snippet = false,
    bool literal = false,
  }) {
    var text = literal ? source : markdownPreviewText(source);
    if (query.isEmpty) return TextSpan(text: text);
    final pattern = RegExp(
      RegExp.escape(query),
      caseSensitive: false,
      unicode: true,
    );
    final first = pattern.firstMatch(text);
    if (snippet && first != null && first.start > 40)
      text = '…${text.substring(first.start - 30)}';
    final spans = <InlineSpan>[];
    var end = 0;
    for (final match in pattern.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(end, match.start)));
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      end = match.end;
    }
    spans.add(TextSpan(text: text.substring(end)));
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) => formatted
      ? _FormattedMessagePreview(
          text: text,
          style: style ?? DefaultTextStyle.of(context).style,
          maxLines: maxLines,
        )
      : Text.rich(
          TextSpan(
            children: [
              ...prefix,
              span(
                context,
                text,
                query: query,
                snippet: snippet,
                literal: literal,
              ),
            ],
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
}

/// A compact, non-interactive rendering; tapping the quote opens its source.
class _FormattedMessagePreview extends StatelessWidget {
  const _FormattedMessagePreview({
    required this.text,
    required this.style,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [CjkStrongSyntax()],
      encodeHtml: false,
    );
    final nodes = document.parseLines(text.split('\n'));
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < nodes.length; i++) ...[
            if (i > 0) const TextSpan(text: '\n'),
            _span(nodes[i]),
          ],
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  InlineSpan _span(md.Node node) {
    if (node is md.Text) return TextSpan(text: node.text);
    final element = node as md.Element;
    if (element.tag == 'br') return const TextSpan(text: '\n');
    if (element.tag == 'img') {
      final alt = element.attributes['alt'] ?? '';
      return TextSpan(text: alt.isEmpty ? '[图片]' : '[图片] $alt');
    }
    final children = element.children ?? const <md.Node>[];
    final block = {'ul', 'ol', 'table', 'thead', 'tbody', 'tr'};
    return TextSpan(
      style: switch (element.tag) {
        'strong' ||
        'h1' ||
        'h2' ||
        'h3' ||
        'h4' ||
        'h5' ||
        'h6' => const TextStyle(fontWeight: FontWeight.w600),
        'em' => const TextStyle(fontStyle: FontStyle.italic),
        'del' => const TextStyle(decoration: TextDecoration.lineThrough),
        'code' => const TextStyle(fontFamily: 'monospace'),
        'a' => const TextStyle(fontWeight: FontWeight.w500),
        _ => null,
      },
      children: [
        if (element.tag == 'li') const TextSpan(text: '• '),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0 && block.contains(element.tag))
            TextSpan(text: element.tag == 'tr' ? ' · ' : '\n'),
          _span(children[i]),
        ],
      ],
    );
  }
}
