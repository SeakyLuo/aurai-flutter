import '../../domain/error_message.dart';
import 'package:flutter/material.dart';

class PaginationListener extends StatefulWidget {
  const PaginationListener({
    super.key,
    required this.hasMore,
    required this.loadMore,
    required this.child,
    this.loadAtStart = false,
  });
  final bool hasMore;
  final bool loadAtStart;
  final Future<void> Function() loadMore;
  final Widget child;

  @override
  State<PaginationListener> createState() => _PaginationListenerState();
}

class _PaginationListenerState extends State<PaginationListener> {
  bool _loading = false;

  Future<void> _load() async {
    if (_loading || !widget.hasMore) return;
    _loading = true;
    try {
      await widget.loadMore();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败，请重试：${errorMessage(error)}'),
            action: SnackBarAction(label: '重试', onPressed: _load),
          ),
        );
      }
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical &&
              ((notification is ScrollUpdateNotification &&
                      notification.dragDetails != null) ||
                  (notification is OverscrollNotification &&
                      notification.dragDetails != null)) &&
              (widget.loadAtStart
                      ? notification.metrics.extentBefore
                      : notification.metrics.extentAfter) <
                  240) {
            _load();
          }
          return false;
        },
        child: widget.child,
      );
}
