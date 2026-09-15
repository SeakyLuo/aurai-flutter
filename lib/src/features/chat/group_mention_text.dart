import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../../app/global_ui.dart';

TextStyle groupMentionStyle(BuildContext context) => TextStyle(
  color: Theme.of(context).brightness == Brightness.dark
      ? GlobalUI.primaryLight
      : GlobalUI.onPrimary,
  decoration: TextDecoration.none,
);

class MemberMentionSyntax extends md.InlineSyntax {
  MemberMentionSyntax(this.members)
    : super(
        '@(?:${([...members.keys, '所有人']..sort((a, b) => b.length.compareTo(a.length))).map(RegExp.escape).join('|')})(?![a-zA-Z0-9_])',
      );
  final Map<String, String> members;
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match[0]!;
    final element = md.Element.text('member-mention', text);
    final id = members[text.substring(1)];
    if (id != null) element.attributes['sender'] = id;
    parser.addNode(element);
    return true;
  }
}

class MemberMentionBuilder extends MarkdownElementBuilder {
  MemberMentionBuilder(this.onOpen);
  final ValueChanged<String>? onOpen;
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => GestureDetector(
    onTap: element.attributes['sender'] == null
        ? null
        : () => onOpen?.call(element.attributes['sender']!),
    child: Text(
      element.textContent,
      style: (parentStyle ?? preferredStyle)?.merge(groupMentionStyle(context)),
    ),
  );
}

class GroupMentionText extends StatefulWidget {
  const GroupMentionText({
    super.key,
    required this.text,
    required this.style,
    required this.members,
    this.onOpen,
    this.maxLines,
    this.overflow,
  });
  final String text;
  final TextStyle style;
  final Map<String, String> members;
  final ValueChanged<String>? onOpen;
  final int? maxLines;
  final TextOverflow? overflow;
  @override
  State<GroupMentionText> createState() => _GroupMentionTextState();
}

class _GroupMentionTextState extends State<GroupMentionText> {
  final _recognizers = <TapGestureRecognizer>[];
  void _clear() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final names = widget.members.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(
      r'\[((?:\\.|[^\]])+)\]\(aurai://member/([^)]+)\)|@所有人' +
          (names.isEmpty
              ? ''
              : '|@(?:${names.map(RegExp.escape).join('|')})(?![a-zA-Z0-9_])'),
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in pattern.allMatches(widget.text)) {
      spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      final label =
          match.group(1)?.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!) ??
          match[0]!;
      final id = match.group(2) == null
          ? widget.members[label.substring(1)]
          : Uri.decodeComponent(match.group(2)!);
      TapGestureRecognizer? recognizer;
      if (id != null && widget.onOpen != null) {
        recognizer = TapGestureRecognizer()..onTap = () => widget.onOpen!(id);
        _recognizers.add(recognizer);
      }
      spans.add(
        TextSpan(
          text: label,
          style: groupMentionStyle(context),
          recognizer: recognizer,
        ),
      );
      cursor = match.end;
    }
    spans.add(TextSpan(text: widget.text.substring(cursor)));
    return Text.rich(
      TextSpan(children: spans),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
