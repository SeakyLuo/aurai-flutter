import 'package:flutter/widgets.dart';

class ChatScrollAnchor extends InheritedWidget {
  const ChatScrollAnchor({
    super.key,
    required this.preserve,
    required super.child,
  });

  final VoidCallback preserve;

  static void beforeResize(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ChatScrollAnchor>()?.preserve();

  @override
  bool updateShouldNotify(ChatScrollAnchor oldWidget) => false;
}
