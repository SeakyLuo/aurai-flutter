import 'package:flutter/material.dart';

/// Swipeable pages retain their state after their first visit.
class RetainedTabView extends StatefulWidget {
  const RetainedTabView({
    super.key,
    required this.index,
    required this.onChanged,
    required this.children,
    this.swipeEnabled = true,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<Widget> children;
  final bool swipeEnabled;

  @override
  State<RetainedTabView> createState() => _RetainedTabViewState();
}

class _RetainedTabViewState extends State<RetainedTabView> {
  late final _controller = PageController(initialPage: widget.index);
  int? _target;

  @override
  void didUpdateWidget(RetainedTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.hasClients) return;
    if (oldWidget.swipeEnabled && !widget.swipeEnabled) {
      _target = null;
      _controller.jumpToPage(widget.index);
      return;
    }
    if (oldWidget.index == widget.index) return;
    if (_target == null && _controller.page?.round() == widget.index) return;
    _target = widget.index;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(widget.index);
    } else {
      _controller.animateToPage(
        widget.index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 && notification.dragDetails != null)
            _target = null;
          return false;
        },
        child: PageView.builder(
          controller: _controller,
          physics: widget.swipeEnabled
              ? null
              : const NeverScrollableScrollPhysics(),
          itemCount: widget.children.length,
          onPageChanged: (index) {
            if (_target != null && _target != index) return;
            _target = null;
            if (index != widget.index) widget.onChanged(index);
          },
          itemBuilder: (context, index) => _RetainedPage(
            child: TickerMode(
              enabled: index == widget.index,
              child: widget.children[index],
            ),
          ),
        ),
      );
}

class _RetainedPage extends StatefulWidget {
  const _RetainedPage({required this.child});
  final Widget child;

  @override
  State<_RetainedPage> createState() => _RetainedPageState();
}

class _RetainedPageState extends State<_RetainedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
