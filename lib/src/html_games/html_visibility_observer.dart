import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports geometry changes without maintaining a periodic visibility timer.
class HtmlVisibilityObserver extends SingleChildRenderObjectWidget {
  const HtmlVisibilityObserver({
    super.key,
    required this.onChanged,
    required super.child,
  });
  final VoidCallback onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GeometryObserver(onChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _GeometryObserver renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

class _GeometryObserver extends RenderProxyBox {
  _GeometryObserver(this.onChanged);
  VoidCallback onChanged;
  Rect? _bounds;

  @override
  void paint(PaintingContext context, Offset offset) {
    final bounds = localToGlobal(Offset.zero) & size;
    if (bounds != _bounds) {
      _bounds = bounds;
      onChanged();
    }
    super.paint(context, offset);
  }
}
