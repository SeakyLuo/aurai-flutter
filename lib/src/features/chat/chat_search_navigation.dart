part of 'chat_page.dart';

typedef _UnreadTarget = ({String id, int count, bool visible});

extension _ChatSearchNavigation on _ChatPageState {
  Future<void> _locateInitialMessage() async {
    final controller = widget.controller;
    final conversation = controller.activeConversation;
    try {
      final id =
          widget.initialMessageId ?? await controller.firstUnreadMessageId();
      if (!mounted || !identical(controller.activeConversation, conversation))
        return;
      if (widget.initialMessageId != null) {
        await _locateSearchMessage(widget.initialMessageId!);
      } else {
        final unreadCount = conversation.unreadMessageCount;
        if (id == null) return;
        final fits = await _unreadFitsReadingArea(id);
        if (!mounted ||
            !identical(controller.activeConversation, conversation) ||
            fits == null) {
          return;
        }
        _unreadTarget.value = (id: id, count: unreadCount, visible: !fits);
      }
    } on Object catch (error) {
      if (mounted) _imageNotice('未读位置加载失败：${errorMessage(error)}');
    } finally {
      _locatingInitialMessage = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleMarkRead();
      });
    }
  }

  Future<bool?> _unreadFitsReadingArea(String id) {
    final view = View.of(context);
    final headerBottom =
        view.padding.top / view.devicePixelRatio +
        _scaffoldKey.currentState!.widget.appBar!.preferredSize.height;
    return _viewportKey.currentState?.unreadFitsViewport(
          id,
          headerBottom: headerBottom,
        ) ??
        Future.value(false);
  }

  void _dismissReachedUnread() {
    final target = _unreadTarget.value;
    if (target == null || !target.visible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _unreadTarget.value != target) return;
      final view = View.of(context);
      final headerBottom =
          view.padding.top / view.devicePixelRatio +
          _scaffoldKey.currentState!.widget.appBar!.preferredSize.height;
      if (_viewportKey.currentState?.hasReachedMessageStart(
            target.id,
            headerBottom: headerBottom,
          ) ==
          true) {
        _unreadTarget.value = null;
      }
    });
  }

  Widget _unreadPositionHint(double top) => Positioned(
    top: top + 8,
    right: 16,
    child: ValueListenableBuilder<_UnreadTarget?>(
      valueListenable: _unreadTarget,
      builder: (context, target, _) => target == null || !target.visible
          ? const SizedBox.shrink()
          : GlassSurface(
              radius: 24,
              child: TextButton(
                onPressed: () async {
                  if (_jumpingToUnread) return;
                  _jumpingToUnread = true;
                  try {
                    await _locateSearchMessage(target.id);
                    if (mounted &&
                        widget.controller.activeConversation.searchMessageId ==
                            target.id) {
                      _unreadTarget.value = null;
                    }
                  } finally {
                    _jumpingToUnread = false;
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: GlobalUI.taskTimeColor(context),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(18, 18),
                      painter: _UnreadArrowPainter(
                        GlobalUI.taskTimeColor(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(target.count > 0 ? '${target.count}条新消息' : '新消息'),
                  ],
                ),
              ),
            ),
    ),
  );

  Future<void> _locateSearchMessage(String messageId) async {
    final controller = widget.controller;
    final conversation = controller.activeConversation;
    try {
      if (!await controller.locateSearchMessage(messageId)) return;
      if (!mounted || !identical(controller.activeConversation, conversation))
        return;
      _focusNode.unfocus();
      _positionSearchResult(messageId);
    } on Object catch (caughtError) {
      if (mounted && identical(controller.activeConversation, conversation)) {
        _scrollToBottom();
        _imageNotice('无法定位这条消息，请重新搜索：${errorMessage(caughtError)}');
      }
    }
  }

  void _applySearchPosition(String messageId) {
    _highlightedMessageId = messageId;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _clearMessageHighlight();
    });
    _followOutput = false;
    _sentMessageId = null;
    _scrollBookmarks[_conversationId] = ChatScrollBookmark(
      messageId,
      .15,
      false,
    );
    _viewportKey = GlobalKey<ChatViewportState>();
  }
}

class _UnreadArrowPainter extends CustomPainter {
  const _UnreadArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(6, 12)
        ..lineTo(12, 6)
        ..lineTo(18, 12)
        ..moveTo(6, 18)
        ..lineTo(12, 12)
        ..lineTo(18, 18),
      paint,
    );
  }

  @override
  bool shouldRepaint(_UnreadArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
