String responseTextWithCitations(Map<String, Object?> content) {
  final text = content['text']! as String;
  final annotations =
      (content['annotations'] as List? ?? const [])
          .cast<Map>()
          .where((annotation) => annotation['type'] == 'url_citation')
          .toList()
        ..sort(
          (a, b) =>
              (a['start_index'] as int).compareTo(b['start_index'] as int),
        );
  final characters = text.runes.toList();
  final result = StringBuffer();
  var offset = 0;
  for (final citation in annotations) {
    final start = citation['start_index']! as int;
    final end = citation['end_index']! as int;
    final uri = Uri.parse(citation['url']! as String);
    if (uri.scheme != 'https' && uri.scheme != 'http') continue;
    // Citation offsets are supplied by the remote provider, in characters.
    if (start < offset || end < start || end > characters.length) continue;
    final title = (citation['title']! as String)
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAllMapped(RegExp(r'[\\\[\]]'), (match) => '\\${match[0]}');
    final url = uri.toString().replaceAll('>', '%3E').replaceAll('<', '%3C');
    result.write(String.fromCharCodes(characters.sublist(offset, start)));
    result.write(' [$title](<$url>)');
    offset = end;
  }
  result.write(String.fromCharCodes(characters.sublist(offset)));
  return result.toString();
}
