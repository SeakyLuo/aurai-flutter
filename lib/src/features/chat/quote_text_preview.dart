import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import 'cjk_strong_syntax.dart';

/// A compact, non-interactive rendering; tapping the quote opens its source.
class QuoteTextPreview extends StatelessWidget {
  const QuoteTextPreview({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

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
      maxLines: 2,
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
