import 'package:markdown/markdown.dart' as md;

import '../../domain/source_reference.dart';

class SourceLinkSyntax extends md.LinkSyntax {
  SourceLinkSyntax(this.sources);
  final Map<String, SourceReference> sources;

  @override
  md.Node createNode(
    String destination,
    String? title, {
    required List<md.Node> Function() getChildren,
  }) {
    final link =
        super.createNode(destination, title, getChildren: getChildren)
            as md.Element;
    final href = link.attributes['href']!;
    final source =
        sources[href] ?? SourceReference.fromLocalLink(href, link.textContent);
    if (source == null || title == '来源' || title?.startsWith('来源：') == true) {
      return link;
    }
    final reference = md.Element.text('source-reference', source.title)
      ..attributes['url'] = source.url;
    if (source.publishedAt != null)
      reference.attributes['publishedAt'] = source.publishedAt!;
    if (source.siteName != null)
      reference.attributes['siteName'] = source.siteName!;
    return md.Element('span', [
      link,
      md.Text(' '),
      md.Element('source-citation', [reference]),
    ]);
  }
}

class SourceCitationSyntax extends md.InlineSyntax {
  SourceCitationSyntax([this.availableSources = const {}])
    : super('$_link(?:[ \\t]*$_link)*');
  final Map<String, SourceReference> availableSources;

  static const _link =
      r'\[((?:\\.|[^\]\\\n])+)\]\((?:<[^>\n]+>|[^\s)]+) +"来源(?:：(?:\\.|[^"\\\n])*)?"\)';
  static final _parts = RegExp(
    r'\[((?:\\.|[^\]\\\n])+)\]\((?:<([^>\n]+)>|([^\s)]+)) +"来源(?:：((?:\\.|[^"\\\n])*))?"\)',
  );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final sources = <md.Node>[];
    final seen = <String>{};
    for (final part in _parts.allMatches(match[0]!)) {
      final url = part[2] ?? part[3]!;
      final uri = Uri.tryParse(url);
      if (uri == null ||
          ((!{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) &&
              SourceReference.fromLocalLink(url, _unescape(part[1]!)) ==
                  null)) {
        return false;
      }
      if (!seen.add(url)) continue;
      final local = SourceReference.fromLocalLink(url, _unescape(part[1]!));
      final source = md.Element.text(
        'source-reference',
        local?.title ?? _unescape(part[1]!),
      )..attributes['url'] = local?.url ?? url;
      final publishedAt = availableSources[url]?.publishedAt;
      if (publishedAt != null) source.attributes['publishedAt'] = publishedAt;
      if (part[4] != null && part[4]!.isNotEmpty) {
        source.attributes['siteName'] = _unescape(part[4]!);
      }
      sources.add(source);
    }
    parser.addNode(md.Element('source-citation', sources));
    return true;
  }

  static String _unescape(String value) =>
      value.replaceAllMapped(RegExp(r'\\(.)'), (match) => match[1]!);
}

List<SourceReference> citationGroup(md.Element element) => [
  for (final child in element.children!.cast<md.Element>())
    SourceReference(
      title: child.textContent,
      url: child.attributes['url']!,
      siteName: child.attributes['siteName'],
      publishedAt: child.attributes['publishedAt'],
    ),
];

List<SourceReference> messageSources(
  String text, {
  Map<String, SourceReference> availableSources = const {},
}) {
  final nodes = md.Document(
    inlineSyntaxes: [
      SourceCitationSyntax(availableSources),
      SourceLinkSyntax(availableSources),
    ],
    extensionSet: md.ExtensionSet.gitHubFlavored,
  ).parseLines(text.split('\n'));
  final sources = <String, SourceReference>{};
  void collect(List<md.Node> nodes) {
    for (final node in nodes.whereType<md.Element>()) {
      if (node.tag == 'source-citation') {
        for (final source in citationGroup(node)) {
          sources.putIfAbsent(source.url, () => source);
        }
      } else if (node.children != null) {
        collect(node.children!);
      }
    }
  }

  collect(nodes);
  return sources.values.toList();
}
