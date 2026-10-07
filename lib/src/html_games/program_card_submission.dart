import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import '../domain/interactive_selection.dart';
import '../domain/message_sender.dart';

/// A reducer-authorized proxy uses the same native selection and vote engine.
Future<InteractiveMessage> submitProgramCard(
  DatabaseExecutor txn, {
  required String conversationId,
  required String programId,
  required String messageId,
  required MessageSender player,
  required MessageSender submitter,
  required String programAction,
  required Object? value,
  String? reason,
}) async {
  final rows = await txn.query(
    'messages',
    columns: ['interactive_json'],
    where: 'id = ? AND conversation_id = ?',
    whereArgs: [messageId, conversationId],
  );
  final card = InteractiveMessage.fromJson(
    (jsonDecode(rows.single['interactive_json'] as String) as Map)
        .cast<String, Object?>(),
  );
  if (card.participation['_programMessage'] != programId || card.closed) {
    throw StateError('这张行动卡已结束或不属于当前小程序');
  }
  card.requireViewer(player.id);
  if (card.anonymous) throw StateError('匿名投票必须由参与者本人提交，不能代投');
  final view = card.viewFor(player.id);
  var button = view.buttons.firstWhere(
    (button) => button['programEvent'] == programAction,
  );
  if (button['disabled'] == true) throw StateError('这个选项已处理');
  if (button['selection'] case final Map config) {
    final selection = InteractiveSelection(config.cast<String, Object?>());
    final values = selection.multiple ? value as List : [value];
    final ids = [
      for (final selected in values)
        selection.options.firstWhere(
          (option) =>
              jsonEncode(
                option.containsKey('value') ? option['value'] : option['id'],
              ) ==
              jsonEncode(selected),
        )['id'],
    ];
    button = selection.resolve(button, selection.multiple ? ids : ids.single);
  }
  final participantRevision = card.participantRevision(player.id) + 1;
  final now = DateTime.now().microsecondsSinceEpoch;
  final next = InteractiveMessage.fromJson({
    ...card.toJson(includeParticipants: true),
    if (card.shared)
      'session': card.engine.submit(player.id, player.name, {
        ...button,
        if (reason != null) 'reason': reason,
      }).runtime,
    'participants': {
      ...card.participants,
      player.id: {
        ...?card.participants[player.id],
        'name': player.name,
        'revision': participantRevision,
        'definitionRevision': card.revision,
        'snapshotCount': card.participants[player.id]?['snapshotCount'] ?? 0,
        'title': view.title,
        'body': view.body,
        'buttons': view.buttons,
        'showStatistics': view.showStatistics,
        'buttonColumns': view.buttonColumns,
        'buttonId': button['id'],
        'label': button['label'],
        if (reason != null) 'reason': reason,
        if (button['selections'] != null) ...{
          'selections': button['selections'],
          'value': button['value'],
        },
        'submittedBy': submitter.id,
        'updatedAt': now,
      },
    },
  });
  final batch = txn.batch();
  batch.update(
    'messages',
    {'interactive_json': jsonEncode(next.toJson(includeParticipants: true))},
    where: 'id = ?',
    whereArgs: [messageId],
  );
  batch.insert('interactive_actions', {
    'message_id': messageId,
    'actor_id': player.id,
    'actor_name': player.name,
    'button_id': button['id'],
    'label': '${submitter.name}代填：${button['label']}',
    'definition_revision': card.revision,
    'participant_revision': participantRevision,
    'before_json': null,
    'created_at': now,
  });
  await batch.commit(noResult: true);
  return next;
}
