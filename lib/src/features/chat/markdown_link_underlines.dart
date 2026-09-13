import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class MarkdownLinkUnderlines extends SingleChildRenderObjectWidget {
  const MarkdownLinkUnderlines({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LinkUnderlines(Theme.of(context).colorScheme.onSurface);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _LinkUnderlines renderObject,
  ) {
    renderObject.color = Theme.of(context).colorScheme.onSurface;
  }
}

class _LinkUnderlines extends RenderPadding {
  _LinkUnderlines(this._color)
    : super(padding: const EdgeInsets.only(bottom: 4));
  Color _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final canvas = context.canvas;
    final pen = Paint()
      ..color = _color.withValues(alpha: .55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipRect(offset & size);
    void drawParagraph(RenderParagraph paragraph) {
      var position = 0;
      void visitSpan(InlineSpan span, bool linked) {
        if (span is TextSpan) {
          final isLink = linked || span.recognizer is TapGestureRecognizer;
          final start = position;
          position += span.text?.length ?? 0;
          if (isLink && position > start) {
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: position),
            );
            for (final box in boxes) {
              final left =
                  paragraph.localToGlobal(
                    Offset(box.left, box.bottom),
                    ancestor: this,
                  ) +
                  offset;
              final right =
                  paragraph.localToGlobal(
                    Offset(box.right, box.bottom),
                    ancestor: this,
                  ) +
                  offset;
              final y = left.dy + 2;
              for (var x = left.dx + .75; x < right.dx - .75; x += 6) {
                canvas.drawLine(
                  Offset(x, y),
                  Offset(math.min(x + 2.5, right.dx - .75), y),
                  pen,
                );
              }
            }
          }
          for (final child in span.children ?? const <InlineSpan>[]) {
            visitSpan(child, isLink);
          }
        } else if (span is PlaceholderSpan) {
          position++;
        }
      }

      visitSpan(paragraph.text, false);
    }

    void visit(RenderObject node) {
      if (node is RenderParagraph) drawParagraph(node);
      node.visitChildren(visit);
    }

    child?.visitChildren(visit);
    if (child is RenderParagraph) drawParagraph(child! as RenderParagraph);
    canvas.restore();
  }
}
