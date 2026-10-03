import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';

class PaginationListener extends StatefulWidget {
  const PaginationListener({
    super.key,
    required this.hasMore,
    required this.loadMore,
    required this.child,
    this.loadAtStart = false,
    this.failed = false,
    this.onRetry,
    this.preloadExtent = 240,
    this.retryBottomInset = 0,
  });
  final bool hasMore;
  final bool failed;
  final Future<void> Function()? onRetry;
  final bool loadAtStart;
  final double preloadExtent;
  final double retryBottomInset;
  final Future<void> Function() loadMore;
  final Widget child;

  @override
  State<PaginationListener> createState() => _PaginationListenerState();
}

class _PaginationListenerState extends State<PaginationListener> {
  bool _loading = false;
  bool _failed = false;

  Future<void> _load({bool retry = false}) async {
    if (_loading || !widget.hasMore || ((_failed || widget.failed) && !retry))
      return;
    setState(() {
      _failed = false;
      _loading = true;
    });
    try {
      await widget.loadMore();
    } on Object catch (error) {
      _failed = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('加载失败，请重试：${errorMessage(error)}')),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final delta = switch (notification) {
            ScrollUpdateNotification() => notification.scrollDelta ?? 0,
            OverscrollNotification() => notification.overscroll,
            _ => 0.0,
          };
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical &&
              (widget.loadAtStart ? delta < 0 : delta > 0) &&
              (widget.loadAtStart
                      ? notification.metrics.extentBefore
                      : notification.metrics.extentAfter) <
                  widget.preloadExtent) {
            _load();
          }
          return false;
        },
        child: Column(
          children: [
            Expanded(child: widget.child),
            if (_failed || widget.failed)
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    12 + widget.retryBottomInset,
                  ),
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            if (widget.onRetry != null) {
                              await widget.onRetry!();
                            } else {
                              await _load(retry: true);
                            }
                          },
                    child: const Text('重试加载'),
                  ),
                ),
              ),
          ],
        ),
      );
}
