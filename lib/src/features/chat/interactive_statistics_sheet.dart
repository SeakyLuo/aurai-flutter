import '../../domain/interactive_selection.dart';
import 'interactive_message_paging.dart';
import 'interactive_snapshot_statistics.dart';
import 'interactive_statistics_overview.dart';
import 'message_time.dart';
import 'question_icon.dart';
import 'interactive_history_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/error_message.dart';
import '../../domain/interactive_message.dart';
import '../../domain/message_sender.dart';
import '../../storage/interactive_action_history.dart';
import '../../storage/interactive_message_store.dart';
import 'member_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

Future<void> showInteractiveStatistics(
  BuildContext context, {
  required Database database,
  required String messageId,
}) {
  final snapshot = InteractivePageScope.of(context)?.snapshot;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => _StatisticsSheet(
      database: database,
      messageId: messageId,
      snapshot: snapshot,
    ),
  );
}

class _StatisticsSheet extends StatefulWidget {
  const _StatisticsSheet({
    required this.database,
    required this.messageId,
    this.actor,
    this.snapshot,
  });
  final Database database;
  final String messageId;
  final String? actor;
  final InteractiveMessage? snapshot;
  @override
  State<_StatisticsSheet> createState() => _StatisticsSheetState();
}

class _StatisticsSheetState extends State<_StatisticsSheet> {
  InteractiveMessage? _card;
  Map<String, MessageSender> _senders = {};
  String? _perspective;
  InteractiveOptionKey? _option;
  final _pageStorage = PageStorageBucket();
  List<Map<String, Object?>> _history = [];
  bool _historyLoading = false;
  bool _hasMore = false;
  int _historyGeneration = 0;
  int _loadGeneration = 0;
  bool _closing = false;
  late final StreamSubscription<String> _changes;

  @override
  void initState() {
    super.initState();
    _perspective = widget.actor;
    _changes = InteractiveMessageStore.changes.stream.listen((id) {
      if (id == widget.messageId) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final rows = await widget.database.query(
        'messages',
        columns: ['interactive_json'],
        where: 'id = ? AND kind != ?',
        whereArgs: [widget.messageId, 'system'],
      );
      if (rows.isEmpty) throw StateError('消息已撤回或删除');
      final card = InteractiveMessage.fromJson(
        jsonDecode(rows.single['interactive_json'] as String)
            as Map<String, dynamic>,
      );
      card.requireViewer('user:local');
      final ids = card.visible('visibility')
          ? card.participants.keys.toList()
          : [MessageSender.localUser.id];
      final senders = ids.isEmpty
          ? <Map<String, Object?>>[]
          : await widget.database.query(
              'message_senders',
              where: 'id IN (${List.filled(ids.length, '?').join(',')})',
              whereArgs: ids,
            );
      if (!mounted || generation != _loadGeneration) return;
      final actor = _perspective;
      if (actor != null &&
          (!card.participants.containsKey(actor) ||
              (actor != MessageSender.localUser.id &&
                  !card.visible('visibility')))) {
        throw StateError('该参与者的记录已不可查看');
      }
      final refreshHistory =
          actor != null &&
          card.participants.containsKey(actor) &&
          (_card == null ||
              card.participantRevision(actor) !=
                  _card!.participantRevision(actor));
      setState(() {
        _card = card;
        _senders = {
          for (final row in senders)
            row['id'] as String: MessageSender.fromRow(row),
        };
        if (!card.visible('visibility')) _option = null;
        if ((_perspective != MessageSender.localUser.id &&
                !card.visible('visibility')) ||
            (_perspective != null &&
                !card.participants.containsKey(_perspective))) {
          _perspective = null;
          _historyGeneration++;
          _historyLoading = false;
          _history = [];
        }
      });
      if (refreshHistory && _perspective != null)
        await _loadHistory(latest: true);
    } on Object catch (error) {
      if (!mounted || _closing) return;
      _closing = true;
      _changes.cancel();
      _error(error);
      final route = ModalRoute.of(context)!;
      if (route.isCurrent) {
        Navigator.pop(context);
      } else {
        Navigator.of(context).removeRoute(route);
      }
    }
  }

  Future<void> _loadHistory({bool reset = false, bool latest = false}) async {
    final actor = _perspective!;
    final generation = ++_historyGeneration;
    setState(() => _historyLoading = true);
    try {
      final rows = await readInteractiveHistory(
        widget.database,
        widget.messageId,
        actor,
        before: reset || latest || _history.isEmpty
            ? null
            : _history.last['sequence'] as int,
      );
      if (!mounted || generation != _historyGeneration) return;
      setState(() {
        if (latest) {
          final overlaps = rows.any(
            (row) =>
                _history.any((event) => event['sequence'] == row['sequence']),
          );
          if (!overlaps) {
            _history = [];
            _hasMore = rows.length == 50;
          }
          final events = {
            for (final event in [..._history, ...rows])
              event['sequence'] as int: event,
          };
          _history = events.values.toList()
            ..sort(
              (a, b) => (b['sequence'] as int).compareTo(a['sequence'] as int),
            );
        } else {
          _history = reset ? rows : [..._history, ...rows];
          _hasMore = rows.length == 50;
        }
      });
    } on Object catch (error) {
      _error(error);
    } finally {
      if (mounted && generation == _historyGeneration)
        setState(() => _historyLoading = false);
    }
  }

  Future<void> _openParticipant(String id) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => _StatisticsSheet(
      database: widget.database,
      messageId: widget.messageId,
      actor: id,
    ),
  );

  bool get _atOverview => _perspective == null && _option == null;

  void _back() {
    setState(() {
      if (_perspective != null) {
        _perspective = null;
        _historyGeneration++;
        _historyLoading = false;
      } else {
        _option = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final actor = _perspective;
    final title = actor != null
        ? '参与详情'
        : _option != null
        ? '参与者'
        : '参与情况';
    return PopScope(
      canPop: _atOverview || actor != null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    SettingsGlassAction(
                      label: _atOverview || actor != null ? '关闭' : '返回',
                      icon: _atOverview || actor != null
                          ? Icons.close_rounded
                          : Icons.arrow_back_rounded,
                      iconWidget: _atOverview || actor != null
                          ? const QuestionIcon(type: QuestionIconType.close)
                          : const SettingsIcon(type: SettingsIconType.back),
                      onPressed: _atOverview || actor != null
                          ? () => Navigator.pop(context)
                          : _back,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: PageStorage(
                  bucket: _pageStorage,
                  child: card == null
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : widget.snapshot != null
                      ? InteractiveSnapshotStatistics(card: widget.snapshot!)
                      : actor != null
                      ? _participant(card, actor)
                      : _option != null
                      ? _participants(card)
                      : InteractiveStatisticsOverview(
                          card: card,
                          senders: _senders,
                          onParticipant: _openParticipant,
                          onOption: (option) =>
                              setState(() => _option = option),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _participants(InteractiveMessage card) {
    final option = _option!;
    final people = card.choices.entries
        .where(
          (entry) => selectionEntries(entry.value).any(
            (choice) =>
                choice['buttonId'] == option.$1 && choice['label'] == option.$2,
          ),
        )
        .toList();
    return ListView(
      key: PageStorageKey(('option', option)),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          option.$2,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          '${people.length} 人',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (people.isEmpty) const Text('暂无参与记录'),
        for (final entry in people)
          InteractiveParticipantTile(
            card: card,
            sender: statisticsSender(card, _senders, entry.key),
            actor: entry.key,
            onTap: () => _openParticipant(entry.key),
          ),
      ],
    );
  }

  Widget _participant(InteractiveMessage card, String actor) {
    final state = card.participants[actor]!;
    final updatedAt = DateTime.fromMicrosecondsSinceEpoch(
      state['updatedAt'] as int,
    );
    return ListView(
      key: PageStorageKey(('participant', actor)),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            MemberAvatar(
              sender: statisticsSender(card, _senders, actor),
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statisticsName(card, actor),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    messageTime(updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          card.singleChoice ? '当前选择' : '最近操作',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state['label'] as String,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        const Divider(height: 32),
        const Text(
          '操作记录',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final event in _history)
          InteractiveHistoryTile(
            key: ValueKey(event['sequence']),
            database: widget.database,
            messageId: widget.messageId,
            actorId: actor,
            event: event,
          ),
        if (_historyLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (_hasMore && !_historyLoading)
          TextButton(onPressed: _loadHistory, child: const Text('查看更早记录')),
        if (_history.isEmpty && !_historyLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('暂无操作记录'),
          ),
      ],
    );
  }
}
