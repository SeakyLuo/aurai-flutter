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
import 'interactive_message_view.dart';
import 'member_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

Future<void> showInteractiveStatistics(
  BuildContext context, {
  required Database database,
  required String messageId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => _StatisticsSheet(database: database, messageId: messageId),
);

class _StatisticsSheet extends StatefulWidget {
  const _StatisticsSheet({required this.database, required this.messageId});
  final Database database;
  final String messageId;
  @override
  State<_StatisticsSheet> createState() => _StatisticsSheetState();
}

class _StatisticsSheetState extends State<_StatisticsSheet> {
  InteractiveMessage? _card;
  Map<String, MessageSender> _senders = {};
  String? _perspective;
  InteractiveOptionKey? _option;
  bool _showCurrent = false;
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
      final refreshHistory =
          actor != null &&
          card.participants.containsKey(actor) &&
          card.participantRevision(actor) != _card!.participantRevision(actor);
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
          _showCurrent = false;
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

  void _openParticipant(String id) {
    setState(() {
      _perspective = id;
      _history = [];
      _hasMore = false;
    });
    _loadHistory(reset: true);
  }

  bool get _atOverview => _perspective == null && _option == null;

  void _back() {
    setState(() {
      if (_showCurrent) {
        _showCurrent = false;
      } else if (_perspective != null) {
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
    final title = _showCurrent
        ? '当前页面'
        : actor != null
        ? statisticsName(card!, actor)
        : _option != null
        ? '参与者'
        : card?.title ?? '参与情况';
    return PopScope(
      canPop: _atOverview,
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
                      label: _atOverview ? '关闭' : '返回',
                      icon: _atOverview
                          ? Icons.close_rounded
                          : Icons.arrow_back_rounded,
                      iconWidget: _atOverview
                          ? const QuestionIcon(type: QuestionIconType.close)
                          : const SettingsIcon(type: SettingsIconType.back),
                      onPressed: _atOverview
                          ? () => Navigator.pop(context)
                          : _back,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!_atOverview) ...[
                      const SizedBox(width: 12),
                      SettingsGlassAction(
                        label: '关闭',
                        icon: Icons.close_rounded,
                        iconWidget: const QuestionIcon(
                          type: QuestionIconType.close,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
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
                      : _showCurrent
                      ? _current(card, actor!)
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
    final people = card.participants.entries
        .where(
          (entry) =>
              entry.value['buttonId'] == option.$1 &&
              entry.value['label'] == option.$2,
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

  Widget _current(InteractiveMessage card, String actor) => ListView(
    key: PageStorageKey(('current', actor)),
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    children: [
      InteractiveMessageView(
        card: card,
        actorId: actor,
        readOnly: true,
        onClick: (_, _, _) async => null,
        onOpenLink: (_) async {},
      ),
    ],
  );

  Widget _participant(InteractiveMessage card, String actor) {
    final state = card.participants[actor]!;
    final updatedAt = DateTime.fromMicrosecondsSinceEpoch(
      state['updatedAt'] as int,
    );
    return ListView(
      key: PageStorageKey(('participant', actor)),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemberAvatar(
              sender: statisticsSender(card, _senders, actor),
              size: 44,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.singleChoice ? '当前选择' : '最近操作',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state['label'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
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
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('查看当前页面'),
          trailing: const SettingsIcon(type: SettingsIconType.chevron),
          onTap: () => setState(() => _showCurrent = true),
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
