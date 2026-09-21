import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'chat_timeline.dart';
import 'chat_scrollbar.dart';
import 'chat_entry_size.dart';
import 'chat_scroll_anchor.dart';
import 'pagination_listener.dart';

class ChatScrollBookmark {
  const ChatScrollBookmark(
    this.messageId,
    this.alignment,
    this.followOutput, [
    this.replyAnchorId,
  ]);
  final String messageId;
  final double alignment;
  final bool followOutput;
  final String? replyAnchorId;
}

class ChatViewport extends StatefulWidget {
  const ChatViewport({
    super.key,
    required this.entries,
    required this.padding,
    required this.sentMessageTop,
    required this.followOutput,
    required this.hasEarlierMessages,
    required this.hasLaterMessages,
    required this.loadLaterMessages,
    required this.loadEarlierMessages,
    required this.onBookmark,
    this.onUserScroll,
    this.onScrollToLatest,
    required this.onFollowOutputChanged,
    required this.summaryOwners,
    this.bookmark,
    this.sentMessageId,
    this.showScrollbar = false,
    required this.onContentBelowChanged,
  });

  final List<ChatTimelineEntry> entries;
  final EdgeInsets padding;
  final double sentMessageTop;
  final bool followOutput;
  final bool hasEarlierMessages;
  final bool hasLaterMessages;
  final Future<void> Function() loadLaterMessages;
  final Future<void> Function() loadEarlierMessages;
  final ValueChanged<ChatScrollBookmark> onBookmark;
  final VoidCallback? onUserScroll;
  final VoidCallback? onScrollToLatest;
  final ValueChanged<bool> onFollowOutputChanged;
  final Map<String, String> summaryOwners;
  final ChatScrollBookmark? bookmark;
  final String? sentMessageId;
  final bool showScrollbar;
  final ValueChanged<bool> onContentBelowChanged;

  @override
  State<ChatViewport> createState() => ChatViewportState();
}

class ChatViewportState extends State<ChatViewport> {
  // Message bookmarks own restoration; do not reuse the list package
  // position cache from an earlier viewport or search window.
  final _pageStorage = PageStorageBucket();
  final _items = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  late Map<String, int> _indices;
  ChatScrollBookmark? _anchor;
  late bool _following;
  bool _restoring = false;
  int _scrollRevision = 0;
  bool _userScrolling = false;
  double _height = 1;
  bool _hasLayout = false;
  String? _replyAnchorId;
  final _entryHeights = <String, double>{};
  bool _contentBelow = false;
  bool _bottomSyncQueued = false;
  bool _keepSentMessageAtTop = false;
  bool _sentSyncQueued = false;

  double get _footerHeight {
    final start = _indices[_replyAnchorId];
    if (start == null) return widget.padding.bottom;
    final contentHeight = widget.entries
        .skip(start)
        .fold(0.0, (height, entry) => height + (_entryHeights[entry.id] ?? 0));
    return (_height - widget.sentMessageTop - contentHeight).clamp(
      widget.padding.bottom,
      double.infinity,
    );
  }

  void _measureEntry(String id, double height) {
    if (!mounted || _entryHeights[id] == height) return;
    final previousHeight = _entryHeights[id];
    final previousFooter = _footerHeight;
    _entryHeights[id] = height;
    if (_footerHeight != previousFooter) setState(() {});
    if (_keepSentMessageAtTop) _scheduleSentSync();
    if (_following && previousHeight != null) _scheduleBottomSync();
  }

  double _listAlignment(int index, double itemAlignment) {
    // The first center sliver includes the list's leading padding.
    return itemAlignment - (index == 0 ? widget.padding.top / _height : 0);
  }

  void _scheduleSentSync() {
    if (_sentSyncQueued) return;
    _sentSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sentSyncQueued = false;
      if (!mounted || !_keepSentMessageAtTop || _userScrolling || _restoring)
        return;
      final index = _indices[_replyAnchorId]!;
      final position = _positions.itemPositions.value
          .where((item) => item.index == index)
          .firstOrNull;
      if (position == null ||
          (position.itemLeadingEdge * _height - widget.sentMessageTop).abs() >
              1) {
        _pinSentMessage();
      }
    });
  }

  void _pinSentMessage() {
    final revision = ++_scrollRevision;
    _keepSentMessageAtTop = true;
    _following = false;
    _restoring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _scrollRevision) return;
      if (!_keepSentMessageAtTop) {
        _restoring = false;
        return;
      }
      _items.jumpTo(
        index: _indices[_replyAnchorId]!,
        alignment: _listAlignment(
          _indices[_replyAnchorId]!,
          widget.sentMessageTop / _height,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && revision == _scrollRevision) {
          _restoring = false;
          _rememberPosition();
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _following = widget.followOutput;
    _anchor = widget.bookmark;
    _replyAnchorId = widget.bookmark == null
        ? widget.sentMessageId
        : widget.bookmark!.replyAnchorId;
    _keepSentMessageAtTop =
        widget.bookmark == null && widget.sentMessageId != null;
    _indexEntries();
    _positions.itemPositions.addListener(_rememberPosition);
  }

  void _indexEntries() {
    _indices = {
      for (var i = 0; i < widget.entries.length; i++) widget.entries[i].id: i,
    };
  }

  @override
  void didUpdateWidget(ChatViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.followOutput != oldWidget.followOutput) {
      _following = widget.followOutput;
    }
    final anchor = _anchor;
    final previousIndex = anchor == null ? null : _indices[anchor.messageId];
    if (!identical(widget.entries, oldWidget.entries)) _indexEntries();
    if (widget.sentMessageId != oldWidget.sentMessageId &&
        widget.sentMessageId != null) {
      _replyAnchorId = widget.sentMessageId;
      _pinSentMessage();
      return;
    }
    if (_following &&
        (widget.padding.bottom != oldWidget.padding.bottom ||
            widget.entries.length != oldWidget.entries.length ||
            (widget.entries.isNotEmpty &&
                oldWidget.entries.isNotEmpty &&
                widget.entries.last.id != oldWidget.entries.last.id))) {
      _scheduleBottomSync();
    }
    if (anchor != null && !_following) {
      final nextIndex = _anchorIndex(anchor);
      if (previousIndex != nextIndex) {
        final revision = ++_scrollRevision;
        _restoring = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || revision != _scrollRevision) return;
          _items.jumpTo(
            index: nextIndex,
            alignment: _listAlignment(nextIndex, anchor.alignment),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && revision == _scrollRevision) {
              _restoring = false;
              _rememberPosition();
            }
          });
        });
      }
    }
  }

  int _anchorIndex(ChatScrollBookmark anchor) =>
      _indices[anchor.messageId] ??
      _indices[widget.summaryOwners[anchor.messageId]] ??
      widget.entries.length;

  void _rememberPosition() {
    if (_restoring) return;
    if (_keepSentMessageAtTop) _scheduleSentSync();
    final visible =
        _positions.itemPositions.value
            .where(
              (item) => item.itemTrailingEdge > 0 && item.itemLeadingEdge < 1,
            )
            .toList()
          ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    if (visible.isEmpty) return;
    final last = _positions.itemPositions.value
        .where((item) => item.index == widget.entries.length - 1)
        .firstOrNull;
    final contentBelow =
        last == null ||
        last.itemTrailingEdge > 1 - widget.padding.bottom / _height + 0.01;
    final jumpThreshold = _contentBelow ? 120.0 : 160.0;
    final showJumpToBottom =
        last == null ||
        last.itemTrailingEdge * _height - (_height - widget.padding.bottom) >
            jumpThreshold;
    if (_contentBelow != showJumpToBottom) {
      _contentBelow = showJumpToBottom;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onContentBelowChanged(_contentBelow);
      });
    }
    if (_userScrolling && _following == contentBelow) {
      _following = !contentBelow;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFollowOutputChanged(_following);
      });
    }
    final messages = visible.where(
      (item) => item.index < widget.entries.length,
    );
    if (messages.isEmpty) return;
    final first = messages.first;
    _anchor = ChatScrollBookmark(
      widget.entries[first.index].id,
      first.itemLeadingEdge,
      _following,
      _replyAnchorId,
    );
    widget.onBookmark(_anchor!);
  }

  Future<bool?> unreadFitsViewport(
    String messageId, {
    required double headerBottom,
  }) async {
    // Freeze the entry range; new messages must not enlarge this unread batch.
    final entryIds = widget.entries.map((entry) => entry.id).toList();
    final firstIndex = entryIds.indexOf(messageId);
    if (widget.hasLaterMessages || firstIndex < 0) return false;
    final unreadIds = entryIds.sublist(firstIndex);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    final viewport = context.findRenderObject()! as RenderBox;
    final view = View.of(context);
    final keyboardHeight = view.viewInsets.bottom / view.devicePixelRatio;
    final readableHeight =
        viewport.localToGlobal(Offset.zero).dy +
        viewport.size.height -
        widget.padding.bottom +
        keyboardHeight -
        headerBottom;
    // Size callbacks run after layout. Wait for two unchanged layout frames,
    // including any initial bottom alignment, before committing the decision.
    var heights = [for (final id in unreadIds) _entryHeights[id]];
    var stableFrames = 0;
    while (stableFrames < 2) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      final next = [for (final id in unreadIds) _entryHeights[id]];
      stableFrames =
          !_restoring && !_bottomSyncQueued && listEquals(heights, next)
          ? stableFrames + 1
          : 0;
      heights = next;
    }
    var unreadHeight = 0.0;
    for (final height in heights) {
      // Virtualized entries without a measurement cannot establish a fit.
      if (height == null) return false;
      unreadHeight += height;
      if (unreadHeight > readableHeight) return false;
    }
    return true;
  }

  bool hasReachedMessageStart(String id, {required double headerBottom}) {
    final targetIndex = _indices[id];
    if (targetIndex == null) return false;
    final viewport = context.findRenderObject()! as RenderBox;
    final top = headerBottom - viewport.localToGlobal(Offset.zero).dy;
    final bottom = viewport.size.height - widget.padding.bottom;
    return _positions.itemPositions.value.any((item) {
      final leading = item.itemLeadingEdge * _height;
      final trailing = item.itemTrailingEdge * _height;
      if (trailing <= top || leading >= bottom) return false;
      return item.index < targetIndex ||
          (item.index == targetIndex && leading >= top);
    });
  }

  void _dragScrollbar(double position) {
    _scrollRevision++;
    _restoring = false;
    _userScrolling = true;
    _following = false;
    _keepSentMessageAtTop = false;
    widget.onFollowOutputChanged(false);
    final index = position.floor().clamp(0, widget.entries.length - 1);
    final height = _entryHeights[widget.entries[index].id];
    final withinItem = height == null ? 0.0 : (position - index) * height;
    _items.jumpTo(
      index: index,
      alignment: _listAlignment(
        index,
        (widget.padding.top - withinItem) / _height,
      ),
    );
    widget.onUserScroll?.call();
  }

  void _endScrollbarDrag(bool atEnd) {
    _userScrolling = false;
    if (atEnd) {
      if (widget.onScrollToLatest != null) {
        widget.onScrollToLatest!();
      } else {
        scrollToBottom(interrupt: true);
        widget.onFollowOutputChanged(true);
      }
    } else {
      _rememberPosition();
    }
  }

  void _preserveEntry(String id) {
    final revision = ++_scrollRevision;
    _keepSentMessageAtTop = false;
    final position = _positions.itemPositions.value.firstWhere(
      (item) => item.index == _indices[id],
    );
    _following = false;
    widget.onFollowOutputChanged(false);
    final anchor = ChatScrollBookmark(
      id,
      position.itemLeadingEdge,
      false,
      _replyAnchorId,
    );
    _anchor = anchor;
    widget.onBookmark(anchor);
    _restoring = true;
    // Establish the item's anchor before its height changes, in the same frame.
    _items.jumpTo(
      index: _anchorIndex(anchor),
      alignment: _listAlignment(_anchorIndex(anchor), anchor.alignment),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _scrollRevision) return;
      _restoring = false;
      _rememberPosition();
    });
  }

  void restoreBookmark(ChatScrollBookmark bookmark) {
    final revision = ++_scrollRevision;
    _keepSentMessageAtTop = false;
    _restoring = true;
    _anchor = bookmark;
    _following = bookmark.followOutput;
    setState(() => _replyAnchorId = bookmark.replyAnchorId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _scrollRevision) return;
      final index = _anchorIndex(bookmark);
      _items.jumpTo(
        index: index,
        alignment: _listAlignment(index, bookmark.alignment),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && revision == _scrollRevision) {
          _restoring = false;
          if (_following) scrollToBottom();
          _rememberPosition();
        }
      });
    });
  }

  void _scheduleBottomSync() {
    if (_bottomSyncQueued) return;
    _bottomSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomSyncQueued = false;
      if (!mounted || !_following || _userScrolling || _restoring) return;
      final footer = _positions.itemPositions.value
          .where((item) => item.index == widget.entries.length)
          .firstOrNull;
      final target = _height - widget.padding.bottom;
      if (_replyAnchorId == null &&
          footer != null &&
          (footer.itemLeadingEdge * _height - target).abs() < 0.5) {
        return;
      }
      scrollToBottom();
    });
  }

  void scrollToBottom({bool interrupt = false}) {
    if (!_items.isAttached) return;
    if (interrupt) {
      _scrollRevision++;
      _restoring = false;
      _userScrolling = false;
      _anchor = null;
    } else if (_restoring || _userScrolling) {
      return;
    }
    _following = true;
    _keepSentMessageAtTop = false;
    final footer = _positions.itemPositions.value
        .where((item) => item.index == widget.entries.length)
        .firstOrNull;
    if (_replyAnchorId == null &&
        footer != null &&
        (footer.itemLeadingEdge * _height - (_height - widget.padding.bottom))
                .abs() <
            .5)
      return;
    if (_replyAnchorId != null) setState(() => _replyAnchorId = null);
    _items.jumpTo(
      index: widget.entries.length,
      alignment: (1 - widget.padding.bottom / _height).clamp(0.0, 1.0),
    );
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_rememberPosition);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageStorage(
    bucket: _pageStorage,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heightChanged = _hasLayout && _height != constraints.maxHeight;
        _height = constraints.maxHeight;
        _hasLayout = true;
        if (heightChanged && _following) _scheduleBottomSync();
        if (_keepSentMessageAtTop) _scheduleSentSync();
        final anchor = widget.bookmark;
        final list = PaginationListener(
          hasMore: widget.hasEarlierMessages,
          loadMore: widget.loadEarlierMessages,
          loadAtStart: true,
          child: PaginationListener(
            hasMore: widget.hasLaterMessages,
            loadMore: widget.loadLaterMessages,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0) {
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    _scrollRevision++;
                    _restoring = false;
                    _keepSentMessageAtTop = false;
                    _following = false;
                    widget.onFollowOutputChanged(false);
                    _userScrolling = true;
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                  if (_userScrolling &&
                      (notification is ScrollUpdateNotification ||
                          notification is ScrollEndNotification)) {
                    widget.onUserScroll?.call();
                  }
                  if (notification is ScrollEndNotification && _userScrolling) {
                    _rememberPosition();
                    _userScrolling = false;
                  }
                }
                return false;
              },
              child: ScrollablePositionedList.builder(
                itemScrollController: _items,
                itemPositionsListener: _positions,
                initialScrollIndex: anchor == null && _replyAnchorId != null
                    ? _indices[_replyAnchorId]!
                    : anchor == null || anchor.followOutput
                    ? widget.entries.length
                    : _anchorIndex(anchor),
                initialAlignment: anchor == null && _replyAnchorId != null
                    ? _listAlignment(
                        _indices[_replyAnchorId]!,
                        widget.sentMessageTop / _height,
                      )
                    : anchor == null || anchor.followOutput
                    ? (1 - widget.padding.bottom / _height).clamp(0.0, 1.0)
                    : _listAlignment(_anchorIndex(anchor), anchor.alignment),
                padding: EdgeInsets.only(top: widget.padding.top),
                addAutomaticKeepAlives: true,
                minCacheExtent: 240,
                itemCount: widget.entries.length + 1,
                itemBuilder: (context, index) {
                  if (index == widget.entries.length) {
                    return SizedBox(height: _footerHeight);
                  }
                  final entry = widget.entries[index];
                  return KeyedSubtree(
                    key: PageStorageKey(entry.id),
                    child: ChatScrollAnchor(
                      preserve: () => _preserveEntry(entry.id),
                      child: ChatEntrySize(
                        onHeight: (height) => _measureEntry(entry.id, height),
                        child: entry.builder(context),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        if (!widget.showScrollbar) return list;
        return ChatScrollbar(
          positions: _positions.itemPositions,
          itemCount: widget.entries.length + 1,
          padding: widget.padding,
          onDragTo: _dragScrollbar,
          onDragEnd: _endScrollbarDrag,
          child: list,
        );
      },
    ),
  );
}
