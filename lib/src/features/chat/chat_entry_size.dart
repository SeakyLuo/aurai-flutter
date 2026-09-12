import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ChatEntrySize extends SingleChildRenderObjectWidget {
  const ChatEntrySize({
    super.key,
    required this.onHeight,
    required super.child,
  });
  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _EntrySize(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _EntrySize renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _EntrySize extends RenderProxyBox {
  _EntrySize(this.onHeight);
  ValueChanged<double> onHeight;
  double? _height;

  @override
  void performLayout() {
    super.performLayout();
    if (_height == size.height) return;
    _height = size.height;
    final height = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
