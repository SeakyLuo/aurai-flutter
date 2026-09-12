import 'package:markdown/markdown.dart' as md;

/// Treat Han characters as word boundaries around strong-emphasis delimiters.
/// The original parser still handles nesting, escapes and code spans.
class CjkStrongSyntax extends md.EmphasisSyntax {
  CjkStrongSyntax() : super.asterisk();

  static final _han = RegExp(r'[\u3400-\u9fff\uf900-\ufaff]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final run = match.group(0)!;
    if (run.length != 2) return super.onMatch(parser, match);
    final source = parser.source;
    final start = parser.pos;
    final end = start + run.length;
    final before =
        start > 0 &&
        end < source.length &&
        _han.hasMatch(source[start - 1]) &&
        md.DelimiterRun.unicodePunctuationPattern.hasMatch(source[end]);
    final after =
        start > 0 &&
        end < source.length &&
        _han.hasMatch(source[end]) &&
        md.DelimiterRun.unicodePunctuationPattern.hasMatch(source[start - 1]);
    if (!before && !after) return super.onMatch(parser, match);

    // Only delimiter classification sees punctuation; text and offsets stay intact.
    final boundaries =
        source.substring(0, before ? start - 1 : start) +
        (before ? '。' : '') +
        run +
        (after ? '。' : '') +
        source.substring(after ? end + 1 : end);
    final text = md.Text(run);
    final delimiter = md.DelimiterRun.tryParse(
      md.InlineParser(boundaries, parser.document),
      start,
      end,
      syntax: this,
      tags: tags!,
      node: text,
      allowIntraWord: true,
    )!;
    parser.pushDelimiter(delimiter);
    parser.addNode(text);
    return true;
  }
}
