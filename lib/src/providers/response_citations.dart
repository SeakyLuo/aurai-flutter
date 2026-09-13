import '../domain/source_reference.dart';

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
  int? previousStart;
  int? previousEnd;
  for (final citation in annotations) {
    final start = citation['start_index']! as int;
    final end = citation['end_index']! as int;
    final uri = Uri.parse(citation['url']! as String);
    if (uri.scheme != 'https' && uri.scheme != 'http') continue;
    final source = SourceReference(
      title: citation['title']! as String,
      url: uri.toString(),
    );
    if (start == previousStart && end == previousEnd) {
      result.write(' ${source.markdown}');
      continue;
    }
    // Citation offsets are supplied by the remote provider, in characters.
    if (start < offset || end < start || end > characters.length) continue;
    result.write(String.fromCharCodes(characters.sublist(offset, start)));
    result.write(' ${source.markdown}');
    offset = end;
    previousStart = start;
    previousEnd = end;
  }
  result.write(String.fromCharCodes(characters.sublist(offset)));
  return result.toString();
}
