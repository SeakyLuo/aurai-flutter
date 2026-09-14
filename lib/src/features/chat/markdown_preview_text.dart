import 'package:markdown/markdown.dart' as md;

import 'cjk_strong_syntax.dart';

/// Extract visible text before the list applies its single-line ellipsis.
String markdownPreviewText(String source) {
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    inlineSyntaxes: [CjkStrongSyntax()],
    encodeHtml: false,
  );
  final output = StringBuffer();
  void append(md.Node node) {
    if (node is md.Text) {
      output.write(node.text);
      return;
    }
    final element = node as md.Element;
    if (element.tag == 'img') {
      output.write('[图片]');
      output.write(element.attributes['alt'] ?? '');
      return;
    }
    if (element.tag == 'br' || element.tag == 'hr') {
      output.write(' ');
      return;
    }
    for (final child in element.children ?? const <md.Node>[]) {
      append(child);
    }
    if (const {
      'p',
      'div',
      'li',
      'ul',
      'ol',
      'blockquote',
      'pre',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'td',
      'th',
      'tr',
    }.contains(element.tag)) {
      output.write(' ');
    }
  }

  for (final node in document.parseLines(source.split('\n'))) {
    append(node);
    output.write(' ');
  }
  return output.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
