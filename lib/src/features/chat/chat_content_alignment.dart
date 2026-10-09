import 'package:flutter/widgets.dart';

/// Short chats start below the header; overflowing history follows its end.
double shortChatBottomTarget(
  double height,
  EdgeInsets padding,
  bool alignToStart,
  Iterable<String> entries,
  Map<String, double> entryHeights,
) {
  final bottom = height - padding.bottom;
  if (!alignToStart) return bottom;
  var content = padding.top;
  for (final id in entries) {
    final measured = entryHeights[id];
    // Virtualized entries outside the viewport have not been measured yet.
    if (measured == null) return bottom;
    content += measured;
    if (content >= bottom) return bottom;
  }
  return content;
}
