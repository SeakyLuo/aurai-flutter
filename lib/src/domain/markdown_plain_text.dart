import 'package:markdown/markdown.dart' as md;

import 'cjk_strong_syntax.dart';

final _memberMentionLink = RegExp(
  r'\[((?:\\.|[^\]])+)\]\(aurai://member/[^)]+\)',
);
final _miniappMessageLink = RegExp(
  r'\[((?:\\.|[^\]])+)\]\(aurai://miniapp/[^)]+\)',
);

/// Replaces internal member links with the same `@name` label shown in chat.
String memberMentionsPlainText(String source) => source
    .replaceAllMapped(
      _memberMentionLink,
      (match) =>
          match[1]!.replaceAllMapped(RegExp(r'\\(.)'), (part) => part[1]!),
    )
    .replaceAllMapped(
      _miniappMessageLink,
      (match) =>
          match[1]!.replaceAllMapped(RegExp(r'\\(.)'), (part) => part[1]!),
    );

/// Returns the text users can see after Markdown is rendered.
///
/// Links keep their labels, including member mentions, while their internal
/// destinations are omitted. Block structure is retained for clipboard use.
String markdownPlainText(String source) {
  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    inlineSyntaxes: [CjkStrongSyntax()],
    encodeHtml: false,
  );
  final output = StringBuffer();

  void lineBreak() {
    if (output.isEmpty || output.toString().endsWith('\n')) return;
    output.write('\n');
  }

  void blockBreak() {
    lineBreak();
    if (!output.toString().endsWith('\n\n')) output.write('\n');
  }

  void appendChildren(md.Element element, void Function(md.Node) append) {
    for (final child in element.children ?? const <md.Node>[]) {
      append(child);
    }
  }

  late void Function(md.Node) append;
  append = (node) {
    if (node is md.Text) {
      output.write(node.text);
      return;
    }
    final element = node as md.Element;
    switch (element.tag) {
      case 'img':
        output.write('[图片]');
        output.write(element.attributes['alt'] ?? '');
      case 'br':
        lineBreak();
      case 'hr':
        blockBreak();
      case 'ul':
      case 'ol':
        final ordered = element.tag == 'ol';
        var index = 1;
        for (final child in element.children ?? const <md.Node>[]) {
          final item = child as md.Element;
          lineBreak();
          output.write(ordered ? '${index++}. ' : '• ');
          appendChildren(item, append);
          lineBreak();
        }
        blockBreak();
      case 'td':
      case 'th':
        appendChildren(element, append);
        output.write('\t');
      case 'tr':
        appendChildren(element, append);
        lineBreak();
      case 'p':
      case 'div':
      case 'blockquote':
      case 'pre':
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        appendChildren(element, append);
        blockBreak();
      default:
        appendChildren(element, append);
    }
  };

  for (final node in document.parseLines(source.split('\n'))) {
    append(node);
  }
  return output
      .toString()
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Returns rendered Markdown as compact text for notifications and previews.
String markdownCompactText(String source) =>
    markdownPlainText(source).replaceAll(RegExp(r'\s+'), ' ').trim();
