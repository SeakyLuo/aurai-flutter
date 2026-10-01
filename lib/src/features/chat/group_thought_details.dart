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
    final follow = !_scroll.hasClients || _scroll.position.extentAfter < 48;
    setState(() {
      _running = current != null;
      if (current != null) _activity = current;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (follow) _scroll.jumpTo(_scroll.position.maxScrollExtent);
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
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
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
                  ListView(
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
