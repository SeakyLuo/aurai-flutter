import 'package:flutter/widgets.dart';
import 'chat_controller.dart';

class ImageActionScope extends InheritedWidget {
  const ImageActionScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final ChatController controller;
  static ChatController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ImageActionScope>()!
      .controller;
  @override
  bool updateShouldNotify(ImageActionScope oldWidget) =>
      controller != oldWidget.controller;
}

class ImageMessageScope extends InheritedWidget {
  const ImageMessageScope({
    super.key,
    required this.messageId,
    required super.child,
  });
  final String messageId;
  static String? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ImageMessageScope>()
      ?.messageId;
  @override
  bool updateShouldNotify(ImageMessageScope oldWidget) =>
      messageId != oldWidget.messageId;
}
