import '../../app/glass_notice.dart';
import 'dart:convert';
import 'chat_scroll_anchor.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/error_message.dart';
import '../../domain/interactive_message.dart';
import '../../domain/message_sender.dart';

class InteractiveMessagePaging extends StatefulWidget {
  const InteractiveMessagePaging({
    super.key,
    required this.messageId,
    required this.card,
    required this.database,
    required this.child,
  });
  final String messageId;
  final InteractiveMessage card;
  final Database database;
  final Widget child;
  @override
  State<InteractiveMessagePaging> createState() =>
      _InteractiveMessagePagingState();
}

class _InteractiveMessagePagingState extends State<InteractiveMessagePaging> {
  int? _page;
  int? _sequence;
  InteractiveMessage? _snapshot;
  bool _loading = false;
  int get _count =>
      (widget.card.participants[MessageSender.localUser.id]?['snapshotCount']
              as int? ??
          0) +
      1;

  Future<void> _next() async {
    if (_loading) return;
    final page = ((_page ?? _count - 1) + 1) % _count;
    if (page == _count - 1) {
      ChatScrollAnchor.beforeResize(context);
      setState(() {
        _page = null;
        _sequence = null;
        _snapshot = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await widget.database.query(
        'interactive_actions',
        columns: ['sequence', 'before_json'],
        where: 'message_id = ? AND actor_id = ? AND before_json IS NOT NULL',
        whereArgs: [widget.messageId, MessageSender.localUser.id],
        orderBy: 'sequence ASC',
        limit: 1,
        offset: page,
      );
      final snapshot = InteractiveMessage.fromSnapshot(
        jsonDecode(rows.single['before_json'] as String)
            as Map<String, dynamic>,
        MessageSender.localUser.id,
      );
      if (mounted) {
        ChatScrollAnchor.beforeResize(context);
        setState(() {
          _page = page;
          _sequence = rows.single['sequence'] as int;
          _snapshot = snapshot;
        });
      }
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => InteractivePageScope(
    snapshot: _snapshot,
    sequence: _sequence,
    control: _count < 2
        ? null
        : Semantics(
            button: true,
            label: '第 ${(_page ?? _count - 1) + 1} 页，共 $_count 页，点击下一页',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _loading ? null : _next,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${(_page ?? _count - 1) + 1}/$_count',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
    child: widget.child,
  );
}

class InteractivePageScope extends InheritedWidget {
  const InteractivePageScope({
    super.key,
    required this.snapshot,
    required this.sequence,
    required this.control,
    required super.child,
  });
  final InteractiveMessage? snapshot;
  final int? sequence;
  final Widget? control;
  static InteractivePageScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InteractivePageScope>();
  @override
  bool updateShouldNotify(InteractivePageScope oldWidget) =>
      snapshot != oldWidget.snapshot || control != oldWidget.control;
}
