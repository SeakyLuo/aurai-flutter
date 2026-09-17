import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'mention_text_controller.dart';

class MentionTapRegion extends StatefulWidget {
  const MentionTapRegion({
    super.key,
    required this.controller,
    required this.child,
  });
  final MentionTextController controller;
  final Widget child;

  @override
  State<MentionTapRegion> createState() => _MentionTapRegionState();
}

class _MentionTapRegionState extends State<MentionTapRegion> {
  PointerDownEvent? _down;

  void _open(PointerUpEvent event) {
    final down = _down;
    _down = null;
    if (down == null ||
        down.pointer != event.pointer ||
        event.timeStamp - down.timeStamp >= kLongPressTimeout ||
        (event.position - down.position).distance > kTouchSlop)
      return;
    RenderEditable? editable;
    void visit(RenderObject object) {
      if (object is RenderEditable) {
        editable = object;
      } else {
        object.visitChildren(visit);
      }
    }

    visit(context.findRenderObject()!);
    final render = editable!;
    final point = render.globalToLocal(event.position);
    for (final mention in widget.controller.mentions()) {
      if (mention.senderId == null) continue;
      final boxes = render.getBoxesForSelection(
        TextSelection(
          baseOffset: mention.start,
          extentOffset: mention.start + mention.text.length,
        ),
      );
      if (boxes.any((box) => box.toRect().contains(point))) {
        widget.controller.onOpenMention?.call(mention.senderId!);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) => _down = event,
    onPointerMove: (event) {
      if (_down != null &&
          (event.position - _down!.position).distance > kTouchSlop) {
        _down = null;
      }
    },
    onPointerCancel: (_) => _down = null,
    onPointerUp: _open,
    child: widget.child,
  );
}
