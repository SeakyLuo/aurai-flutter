import 'package:flutter/material.dart';

class DrawerDragRegion extends StatefulWidget {
  const DrawerDragRegion({
    super.key,
    required this.builder,
    required this.onOpen,
  });
  final WidgetBuilder builder;
  final VoidCallback onOpen;

  @override
  State<DrawerDragRegion> createState() => _DrawerDragRegionState();
}

class _DrawerDragRegionState extends State<DrawerDragRegion> {
  double _distance = 0;
  bool _opened = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) {
      _distance = 0;
      _opened = false;
    },
    onHorizontalDragUpdate: (details) {
      _distance += details.delta.dx;
      if (!_opened && _distance > 48) {
        _opened = true;
        widget.onOpen();
      }
    },
    child: widget.builder(context),
  );
}
