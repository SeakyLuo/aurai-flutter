import 'package:flutter/widgets.dart';

class ChatTimelineEntry {
  const ChatTimelineEntry(this.id, this.builder, {this.preserveState = false});
  final String id;
  final WidgetBuilder builder;
  final bool preserveState;
}
