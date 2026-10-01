part of 'group_activity_sheet.dart';

class _GroupThoughtDetails extends StatefulWidget {
  const _GroupThoughtDetails({
    required this.controller,
    required this.conversationId,
    required this.activity,
    this.reasonTitle,
    this.reason,
  });
  final ChatController controller;
  final String conversationId;
  final GroupMemberActivity activity;
  final String? reasonTitle;
  final String? reason;

  @override
  State<_GroupThoughtDetails> createState() => _GroupThoughtDetailsState();
}

class _GroupThoughtDetailsState extends State<_GroupThoughtDetails> {
  final _scroll = ScrollController();
  late GroupMemberActivity _activity = widget.activity;
  late final _updates = Listenable.merge([
    widget.controller,
    widget.controller.groupActivityChanges,
    widget.controller.groupSleepChanges,
  ]);
  bool _running = true;
  bool _showJumpToBottom = false;
  bool _followBottom = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateJumpButton);
    _updates.addListener(_sync);
    _sync();
  }

  void _sync() {
    final current = widget.controller
        .groupActivitiesFor(widget.conversationId)
        .where((activity) => activity.runId == widget.activity.runId)
        .firstOrNull;
    setState(() {
      _running = current != null;
      if (current != null) _activity = current;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_followBottom) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      _updateJumpButton();
    });
  }

  void _updateJumpButton() {
    final threshold = _showJumpToBottom ? 120.0 : 160.0;
    final show = _scroll.position.extentAfter > threshold;
    if (show != _showJumpToBottom) {
      setState(() => _showJumpToBottom = show);
    }
  }

  void _jumpToBottom() {
    _followBottom = true;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _followBottom = false;
    } else if (notification is ScrollUpdateNotification &&
        notification.scrollDelta! < 0) {
      _followBottom = false;
    } else if (notification is ScrollEndNotification) {
      _followBottom = notification.metrics.extentAfter <= 1;
    }
    return false;
  }

  @override
  void dispose() {
    _updates.removeListener(_sync);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _ActivitySheetHeader(
              title: _activity.sender.name,
              avatar: Semantics(
                button: true,
                label: '查看${_activity.sender.name}的资料',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => AiContactPage(
                        controller: widget.controller,
                        senderId: _activity.sender.id,
                        groupId: widget.conversationId,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: MemberAvatar(sender: _activity.sender, size: 24),
                  ),
                ),
              ),
              trailing: _running
                  ? _StopMemberButton(
                      controller: widget.controller,
                      conversationId: widget.conversationId,
                      activity: _activity,
                    )
                  : null,
            ),
            Expanded(
              child: ScrollAwareJumpStack(
                fit: StackFit.expand,
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                      children: [
                        if (widget.reason != null) ...[
                          Text(
                            widget.reasonTitle!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            widget.reason!,
                            style: const TextStyle(fontSize: 15, height: 1.65),
                          ),
                        ],
                        if (_activity.thoughts.isNotEmpty)
                          SelectableText(
                            _activity.thoughts.join('\n\n'),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.65,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_showJumpToBottom)
                    Positioned(
                      right: 16,
                      bottom: 8,
                      child: Center(
                        child: JumpToBottomButton(
                          iconOnly: true,
                          onPressed: _jumpToBottom,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
