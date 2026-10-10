import 'package:flutter/widgets.dart';

/// Message list spacing belongs to the list item, outside its bubble surface.
class ChatMessageSpacing extends StatelessWidget {
  const ChatMessageSpacing({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: child);
}
