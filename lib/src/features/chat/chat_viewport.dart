import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'chat_timeline.dart';
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
    required this.onFollowOutputChanged,
    required this.summaryOwners,
    this.bookmark,
    this.sentMessageId,
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
  final ValueChanged<bool> onFollowOutputChanged;
  final Map<String, String> summaryOwners;
  final ChatScrollBookmark? bookmark;
  final String? sentMessageId;
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
  bool _userScrolling = false;
  double _height = 1;
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
    final previousFooter = _footerHeight;
    _entryHeights[id] = height;
    if (_footerHeight != previousFooter) setState(() {});
    if (_keepSentMessageAtTop) _scheduleSentSync();
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
    _keepSentMessageAtTop = true;
    _following = false;
    _restoring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
        if (mounted) {
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
    _following = widget.followOutput;
    final anchor = _anchor;
    final previousIndex = anchor == null ? null : _indices[anchor.messageId];
    if (!identical(widget.entries, oldWidget.entries)) _indexEntries();
    if (widget.sentMessageId != oldWidget.sentMessageId &&
        widget.sentMessageId != null) {
      _replyAnchorId = widget.sentMessageId;
      _pinSentMessage();
      return;
    }
    if (_following && widget.padding.bottom != oldWidget.padding.bottom) {
      _scheduleBottomSync();
    }
    if (anchor != null && !_following) {
      final nextIndex = _anchorIndex(anchor);
      if (previousIndex != nextIndex) {
        _restoring = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _items.jumpTo(
            index: nextIndex,
            alignment: _listAlignment(nextIndex, anchor.alignment),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
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
    if (_contentBelow != contentBelow) {
      _contentBelow = contentBelow;
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

  void _preserveEntry(String id) {
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
      if (!mounted) return;
      _restoring = false;
      _rememberPosition();
    });
  }

  void restoreBookmark(ChatScrollBookmark bookmark) {
    _keepSentMessageAtTop = false;
    _restoring = true;
    _anchor = bookmark;
    _following = bookmark.followOutput;
    setState(() => _replyAnchorId = bookmark.replyAnchorId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = _anchorIndex(bookmark);
      _items.jumpTo(
        index: index,
        alignment: _listAlignment(index, bookmark.alignment),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
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

  void scrollToBottom() {
    if (!_items.isAttached || _restoring || _userScrolling) return;
    _following = true;
    _keepSentMessageAtTop = false;
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
        final heightChanged = _height != constraints.maxHeight;
        _height = constraints.maxHeight;
        if (heightChanged && _following) _scheduleBottomSync();
        if (_keepSentMessageAtTop) _scheduleSentSync();
        final anchor = widget.bookmark;
        return PaginationListener(
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
                    _keepSentMessageAtTop = false;
                    _userScrolling = true;
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                  if (notification is ScrollEndNotification) {
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
                addAutomaticKeepAlives: false,
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
      },
    ),
  );
}
