part of 'group_activity_sheet.dart';

class GroupRunDetailsLayout extends StatefulWidget {
  const GroupRunDetailsLayout({
    super.key,
    required this.controller,
    required this.sender,
    required this.children,
    this.conversationId,
    this.activity,
    this.followBottom = true,
    this.trailing,
  });

  final ChatController controller;
  final MessageSender sender;
  final String? conversationId;
  final GroupMemberActivity? activity;
  final List<Widget> children;
  final bool followBottom;
  final Widget? trailing;

  @override
  State<GroupRunDetailsLayout> createState() => _GroupRunDetailsLayoutState();
}

class _GroupRunDetailsLayoutState extends State<GroupRunDetailsLayout> {
  final _scroll = ScrollController();
  bool _showJumpToBottom = false;
  late bool _followBottom = widget.followBottom;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateJumpButton);
    _syncScroll();
  }

  @override
  void didUpdateWidget(GroupRunDetailsLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncScroll();
  }

  void _syncScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_followBottom) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      _updateJumpButton();
    });
  }

  void _updateJumpButton() {
    final threshold = _showJumpToBottom ? 120.0 : 160.0;
    final show = _scroll.position.extentAfter > threshold;
    if (show != _showJumpToBottom) setState(() => _showJumpToBottom = show);
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
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSheetSurface(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _ActivitySheetHeader(
              title: widget.sender.displayName,
              avatar: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: MemberProfileAvatar(
                  controller: widget.controller,
                  sender: widget.sender,
                  groupId: widget.conversationId,
                  size: 24,
                ),
              ),
              trailing:
                  widget.trailing ??
                  (widget.activity == null
                      ? null
                      : _StopMemberButton(
                          controller: widget.controller,
                          conversationId: widget.conversationId!,
                          activity: widget.activity!,
                        )),
            ),
            Expanded(
              child: ScrollAwareJumpStack(
                fit: StackFit.expand,
                children: [
                  NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      children: widget.children,
                    ),
                  ),
                  if (_showJumpToBottom)
                    Positioned(
                      right: 16,
                      bottom: 8,
                      child: Center(
                        child: JumpToBottomButton(
                          iconOnly: true,
                          onPressed: () {
                            _followBottom = true;
                            _scroll.jumpTo(_scroll.position.maxScrollExtent);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
