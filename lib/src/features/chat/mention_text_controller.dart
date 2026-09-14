import 'package:flutter/material.dart';
import 'group_mention_text.dart';
import '../../domain/draft_mention.dart';

class MentionTextController extends TextEditingController {
  MentionTextController(this.mentions);
  final List<DraftMention> Function() mentions;

  @override
  set value(TextEditingValue next) {
    final previous = value;
    if (next.text != previous.text && next.selection.isValid) {
      var start = 0;
      while (start < previous.text.length &&
          start < next.text.length &&
          previous.text[start] == next.text[start]) {
        start++;
      }
      var end = previous.text.length;
      var nextEnd = next.text.length;
      while (end > start &&
          nextEnd > start &&
          previous.text[end - 1] == next.text[nextEnd - 1]) {
        end--;
        nextEnd--;
      }
      if (end > start) {
        var from = start;
        var to = end;
        for (final mention in mentions()) {
          final limit = mention.start + mention.text.length;
          if (mention.start < end && limit > start) {
            if (mention.start < from) from = mention.start;
            if (limit > to) to = limit;
          }
        }
        if (from != start || to != end) {
          final replacement = next.text.substring(start, nextEnd);
          final removedBefore = start - from;
          int offset(int position) {
            if (position <= from) return position;
            if (position <= nextEnd) return from + replacement.length;
            final after = position - removedBefore - (to - end);
            return after < from + replacement.length
                ? from + replacement.length
                : after;
          }

          next = TextEditingValue(
            text: previous.text.replaceRange(from, to, replacement),
            selection: TextSelection(
              baseOffset: offset(next.selection.baseOffset),
              extentOffset: offset(next.selection.extentOffset),
            ),
          );
        }
      }
    }
    super.value = next;
  }

  void refreshMentions() => notifyListeners();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final mention in [
      ...mentions(),
    ]..sort((a, b) => a.start.compareTo(b.start))) {
      spans.add(TextSpan(text: text.substring(cursor, mention.start)));
      spans.add(
        TextSpan(text: mention.text, style: groupMentionStyle(context)),
      );
      cursor = mention.start + mention.text.length;
    }
    spans.add(TextSpan(text: text.substring(cursor)));
    return TextSpan(style: style, children: spans);
  }
}
