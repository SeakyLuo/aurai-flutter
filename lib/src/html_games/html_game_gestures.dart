import 'dart:ui' show Rect;
import 'package:flutter/gestures.dart';

/// Only page-declared gesture regions take priority over the chat scroll view.
class HtmlGameGestureRecognizer extends EagerGestureRecognizer {
  HtmlGameGestureRecognizer(this.regions);

  final List<Rect> Function() regions;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      regions().any((rect) => rect.contains(event.localPosition)) &&
      super.isPointerAllowed(event);
}
