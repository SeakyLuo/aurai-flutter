import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/error_message.dart';
import '../../domain/interactive_message.dart';
import '../../domain/message_sender.dart';
import '../../storage/interactive_action_history.dart';
import 'interactive_message_view.dart';
import 'message_time.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class InteractiveHistoryPage extends StatefulWidget {
  const InteractiveHistoryPage({
    super.key,
    required this.database,
    required this.messageId,
  });
  final Database database;
  final String messageId;
  @override
  State<InteractiveHistoryPage> createState() => _InteractiveHistoryPageState();
}

class _InteractiveHistoryPageState extends State<InteractiveHistoryPage> {
  final _events = <Map<String, Object?>>[];
  bool _loading = false;
  bool _more = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await readInteractiveHistory(
        widget.database,
        widget.messageId,
        MessageSender.localUser.id,
        before: _events.isEmpty ? null : _events.last['sequence'] as int,
      );
      if (!mounted) return;
      setState(() {
        _events.addAll(page);
        _more = page.length == 50;
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
        if (_events.isEmpty) Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(title: '查看历史', onBack: () => Navigator.pop(context)),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          if (_events.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('每次点按前的卡片', style: TextStyle(fontSize: 14)),
            ),
          for (final event in _events)
            InteractiveHistoryTile(
              database: widget.database,
              messageId: widget.messageId,
              actorId: MessageSender.localUser.id,
              event: event,
            ),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (!_loading && _events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('还没有点按记录')),
            ),
          if (!_loading && _events.isNotEmpty && _more)
            TextButton(onPressed: _load, child: const Text('查看更早记录')),
        ],
      ),
    ),
  );
}

class InteractiveHistoryTile extends StatelessWidget {
  const InteractiveHistoryTile({
    super.key,
    required this.database,
    required this.messageId,
    required this.actorId,
    required this.event,
  });
  final Database database;
  final String messageId, actorId;
  final Map<String, Object?> event;

  Future<void> _open(BuildContext context) async {
    try {
      final rows = await database.query(
        'messages',
        columns: ['interactive_json'],
        where: 'id = ? AND kind != ?',
        whereArgs: [messageId, 'system'],
      );
      if (rows.isEmpty) throw StateError('消息已删除或撤回');
      final current = InteractiveMessage.fromJson(
        jsonDecode(rows.single['interactive_json'] as String)
            as Map<String, dynamic>,
      );
      if (actorId != MessageSender.localUser.id &&
          !current.visible('visibility'))
        throw StateError('这条消息尚未公开其他参与者的记录');
      final snapshots = await database.query(
        'interactive_actions',
        columns: ['before_json'],
        where: 'message_id = ? AND actor_id = ? AND sequence = ?',
        whereArgs: [messageId, actorId, event['sequence']],
      );
      if (snapshots.isEmpty) throw StateError('这条操作记录已删除');
      final json =
          jsonDecode(snapshots.single['before_json'] as String)
              as Map<String, dynamic>;
      final card = InteractiveMessage.fromSnapshot(json, actorId);
      if (!context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (pageContext) => Scaffold(
            appBar: SettingsAppBar(
              title: '点按前的卡片',
              onBack: () => Navigator.pop(pageContext),
            ),
            body: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    '${messageTime(DateTime.fromMicrosecondsSinceEpoch(event['created_at'] as int))} · 点按“${event['label']}”之前',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InteractiveMessageView(
                    card: card,
                    actorId: actorId,
                    readOnly: true,
                    historical: true,
                    onClick: (_, _, _) async => null,
                    onOpenLink: (_) async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } on Object catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = event['has_snapshot'] == 1;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('点按“${event['label']}”'),
      subtitle: Text(
        '${messageTime(DateTime.fromMicrosecondsSinceEpoch(event['created_at'] as int))}${available ? '' : ' · 旧记录未保存卡片快照'}',
      ),
      trailing: available
          ? const SettingsIcon(type: SettingsIconType.chevron)
          : null,
      onTap: available ? () => _open(context) : null,
    );
  }
}
