import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ChatScrollbar extends StatefulWidget {
  const ChatScrollbar({
    super.key,
    required this.positions,
    required this.itemCount,
    required this.padding,
    required this.child,
  });

  final ValueListenable<Iterable<ItemPosition>> positions;
  final int itemCount;
  final EdgeInsets padding;
  final Widget child;

  @override
  State<ChatScrollbar> createState() => _ChatScrollbarState();
}

class _ChatScrollbarState extends State<ChatScrollbar> {
  bool _scrolling = false;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0) return false;
          if (notification is ScrollStartNotification ||
              notification is ScrollUpdateNotification ||
              notification is OverscrollNotification) {
            if (!_scrolling) setState(() => _scrolling = true);
          } else if (notification is ScrollEndNotification) {
            if (_scrolling) setState(() => _scrolling = false);
          }
          return false;
        },
        child: widget.child,
      ),
      Positioned(
        top: widget.padding.top,
        bottom: widget.padding.bottom,
        right: 3,
        width: 3,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: _scrolling ? 1 : 0,
            duration: Duration(milliseconds: _scrolling ? 80 : 250),
            child: LayoutBuilder(
              builder: (context, constraints) => ValueListenableBuilder(
                valueListenable: widget.positions,
                builder: (context, items, _) {
                  final visible =
                      items
                          .where(
                            (item) =>
                                item.itemTrailingEdge > 0 &&
                                item.itemLeadingEdge < 1,
                          )
                          .toList()
                        ..sort((a, b) => a.index.compareTo(b.index));
                  if (visible.isEmpty) return const SizedBox.shrink();
                  final first = visible.first;
                  final last = visible.last;
                  double fraction(ItemPosition item, double edge) =>
                      ((edge - item.itemLeadingEdge) /
                              (item.itemTrailingEdge - item.itemLeadingEdge))
                          .clamp(0.0, 1.0);
                  final start = first.index + fraction(first, 0);
                  final end = last.index + fraction(last, 1);
                  final extent = end - start;
                  if (extent >= widget.itemCount)
                    return const SizedBox.shrink();
                  final height = constraints.maxHeight;
                  final thumb = math.min(
                    height,
                    math.max(28.0, height * extent / widget.itemCount),
                  );
                  final offset =
                      (height - thumb) *
                      (start / (widget.itemCount - extent)).clamp(0.0, 1.0);
                  return Stack(
                    children: [
                      Positioned(
                        top: offset,
                        height: thumb,
                        left: 0,
                        right: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
