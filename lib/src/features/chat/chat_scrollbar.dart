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
    required this.onDragTo,
    required this.onDragEnd,
  });

  final ValueListenable<Iterable<ItemPosition>> positions;
  final int itemCount;
  final EdgeInsets padding;
  final Widget child;
  final ValueChanged<double> onDragTo;
  final ValueChanged<bool> onDragEnd;

  @override
  State<ChatScrollbar> createState() => _ChatScrollbarState();
}

class _ChatScrollbarState extends State<ChatScrollbar> {
  final _scrolling = ValueNotifier(false);
  bool _nextScrolling = false;
  bool _visibilityQueued = false;
  double? _dragOffset;
  double _dragTravel = 0;
  double _dragExtent = 0;
  double _dragRange = 0;

  void _setScrolling(bool value) {
    _nextScrolling = value;
    if (_visibilityQueued) return;
    _visibilityQueued = true;
    // Scroll notifications can arrive during layout. Update only the overlay
    // after that frame, without rebuilding the virtual list under it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityQueued = false;
      if (mounted) _scrolling.value = _nextScrolling;
    });
  }

  @override
  void dispose() {
    _scrolling.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0) return false;
          if (notification is ScrollStartNotification ||
              notification is ScrollUpdateNotification ||
              notification is OverscrollNotification) {
            _setScrolling(true);
          } else if (notification is ScrollEndNotification) {
            _setScrolling(false);
          }
          return false;
        },
        child: widget.child,
      ),
      Positioned(
        top: widget.padding.top,
        bottom: widget.padding.bottom,
        right: 0,
        width: 24,
        child: LayoutBuilder(
          builder: (context, constraints) => ValueListenableBuilder(
            valueListenable: widget.positions,
            builder: (context, items, _) {
              final viewportHeight =
                  constraints.maxHeight + widget.padding.vertical;
              final readableStart = widget.padding.top / viewportHeight;
              final readableEnd = 1 - widget.padding.bottom / viewportHeight;
              final visible =
                  items
                      .where(
                        (item) =>
                            item.itemTrailingEdge > readableStart &&
                            item.itemLeadingEdge < readableEnd,
                      )
                      .toList()
                    ..sort((a, b) => a.index.compareTo(b.index));
              if (visible.isEmpty) return const SizedBox.shrink();
              double fraction(ItemPosition item, double edge) =>
                  ((edge - item.itemLeadingEdge) /
                          (item.itemTrailingEdge - item.itemLeadingEdge))
                      .clamp(0.0, 1.0);
              final start =
                  visible.first.index + fraction(visible.first, readableStart);
              final end =
                  visible.last.index + fraction(visible.last, readableEnd);
              final extent = end - start;
              if (_dragOffset == null && extent >= widget.itemCount) {
                return const SizedBox.shrink();
              }
              final height = constraints.maxHeight;
              final thumb = _dragOffset != null
                  ? _dragExtent
                  : math.min(
                      height,
                      math.max(36.0, height * extent / widget.itemCount),
                    );
              final travel = height - thumb;
              final offset =
                  _dragOffset ??
                  travel *
                      (start / (widget.itemCount - extent)).clamp(0.0, 1.0);
              return Stack(
                children: [
                  Positioned(
                    top: offset,
                    height: thumb,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) {
                        setState(() {
                          _dragOffset = offset;
                          _dragTravel = travel;
                          _dragExtent = thumb;
                          _dragRange = widget.itemCount - extent;
                        });
                      },
                      onVerticalDragUpdate: (details) {
                        if (_dragTravel <= 0) return;
                        final next = (_dragOffset! + details.delta.dy).clamp(
                          0.0,
                          _dragTravel,
                        );
                        setState(() => _dragOffset = next);
                        widget.onDragTo(next / _dragTravel * _dragRange);
                      },
                      onVerticalDragEnd: (_) {
                        final atEnd = _dragOffset! >= _dragTravel - 1;
                        setState(() => _dragOffset = null);
                        widget.onDragEnd(atEnd);
                      },
                      onVerticalDragCancel: () {
                        setState(() => _dragOffset = null);
                        widget.onDragEnd(false);
                      },
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _scrolling,
                        builder: (context, scrolling, _) => Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: _dragOffset != null ? 5 : 3,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(
                                    alpha: _dragOffset != null
                                        ? .8
                                        : scrolling
                                        ? .5
                                        : .25,
                                  ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );
}
