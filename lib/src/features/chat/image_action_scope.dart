import 'package:flutter/widgets.dart';
import 'chat_controller.dart';

typedef MessageAttachmentSelection = ({
  BuildContext context,
  String quoteText,
  Widget Function(double maxHeight) preview,
  Future<void> Function() copy,
});

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
    required this.onOpenMessageMenu,
    required super.child,
  });
  final String messageId;
  final Future<void> Function({MessageAttachmentSelection? attachment})?
  onOpenMessageMenu;
  static String? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ImageMessageScope>()?.messageId;
  static Future<void> Function({MessageAttachmentSelection? attachment})?
  messageMenuOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<ImageMessageScope>()
      ?.onOpenMessageMenu;

  @override
  bool updateShouldNotify(ImageMessageScope oldWidget) =>
      messageId != oldWidget.messageId ||
      onOpenMessageMenu != oldWidget.onOpenMessageMenu;
}
