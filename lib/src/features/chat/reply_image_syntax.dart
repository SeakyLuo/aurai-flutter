import 'package:markdown/markdown.dart' as md;

class ReplyImageSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*\[?!\[');

  List<md.Element>? _images(md.BlockParser parser, String line) {
    final nodes = parser.document.parseInline(line);
    final images = <md.Element>[];
    for (final node in nodes) {
      if (node is md.Text && node.text.trim().isEmpty) continue;
      if (node is! md.Element) return null;
      final md.Element image;
      String? source;
      if (node.tag == 'img') {
        image = node;
      } else if (node.tag == 'a' &&
          node.children?.length == 1 &&
          node.children!.single is md.Element &&
          (node.children!.single as md.Element).tag == 'img') {
        image = node.children!.single as md.Element;
        source = node.attributes['href'];
      } else {
        return null;
      }
      final uri = Uri.tryParse(image.attributes['src'] ?? '');
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
      images.add(
        md.Element.empty('reference-image')
          ..attributes.addAll({
            ...image.attributes,
            if (source != null) 'source': source,
          }),
      );
    }
    return images.isEmpty ? null : images;
  }

  @override
  bool canParse(md.BlockParser parser) =>
      pattern.hasMatch(parser.current.content) &&
      _images(parser, parser.current.content) != null;

  @override
  md.Node parse(md.BlockParser parser) {
    final images = <md.Element>[];
    while (!parser.isDone) {
      final next = _images(parser, parser.current.content);
      if (next == null) break;
      images.addAll(next);
      parser.advance();
    }
    return md.Element('reference-gallery', images);
  }
}

String imageMarkdownForDisplay(String text, bool streaming) {
  if (!streaming) return text;
  final start = text.lastIndexOf('\n') + 1;
  final tail = text.substring(start).trimLeft();
  if (!tail.startsWith('![') && !tail.startsWith('[![')) return text;
  final nodes = md.Document().parseInline(tail);
  final complete = nodes.every(
    (node) =>
        node is md.Text && node.text.trim().isEmpty ||
        node is md.Element &&
            (node.tag == 'img' ||
                node.tag == 'a' &&
                    node.children?.length == 1 &&
                    node.children!.single is md.Element &&
                    (node.children!.single as md.Element).tag == 'img'),
  );
  return complete ? text : text.substring(0, start);
}
