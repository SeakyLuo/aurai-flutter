part of 'memory_controller.dart';

Map<String, Object?> memoryRecord(Map<String, Object?> entry) => {
  'id': entry['id'],
  'text': entry['text'],
  'manual': entry['manual'] == 1,
  'createdAt': DateTime.fromMillisecondsSinceEpoch(
    entry['created_at'] as int,
    isUtc: true,
  ).toIso8601String(),
  'updatedAt': DateTime.fromMillisecondsSinceEpoch(
    entry['updated_at'] as int,
    isUtc: true,
  ).toIso8601String(),
  'sourceConversationId': entry['source_conversation_id'],
  'sourceMessageId': entry['source_message_id'],
};

extension MemoryRecords on MemoryController {
  Map<String, Object?> entryById(String id) {
    final found = entries.where((e) => e['id'] == id);
    if (found.isEmpty) throw StateError('这条记忆已删除，请重新查询');
    return found.single;
  }

  Future<Map<String, Object?>> mutateRecord(
    String operation, {
    String? id,
    String? text,
    required int expectedRevision,
    required String conversationId,
    required String? messageId,
  }) async {
    if (expectedRevision != revision) throw StateError('记忆已变化，请重新查询后操作');
    if (operation != 'delete' && (text!.trim().isEmpty || text.length > 300)) {
      throw StateError('请填写不超过300字的记忆');
    }
    if (id != null) entryById(id);
    _invalidate();
    final epoch = revision;
    final recordId = id ?? newMessageId();
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.transaction((txn) async {
      if (epoch != revision) throw StateError('记忆已变化，请重新查询后操作');
      if (operation == 'delete') {
        await txn.delete(
          'user_memories',
          where: 'id = ? AND $_scopeWhere',
          whereArgs: [recordId, ..._scopeArgs],
        );
      } else if (operation == 'create') {
        await txn.insert('user_memories', {
          'id': recordId,
          'owner_id': ownerId,
          'memory_scope': scope,
          'text': text!.trim(),
          'manual': 1,
          'source_conversation_id': conversationId,
          'source_message_id': messageId,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update(
          'user_memories',
          {'text': text!.trim(), 'manual': 1, 'updated_at': now},
          where: 'id = ? AND $_scopeWhere',
          whereArgs: [recordId, ..._scopeArgs],
        );
      }
    });
    await _reload();
    return operation == 'delete'
        ? {'deleted': true}
        : {'saved': true, 'memory': memoryRecord(entryById(recordId))};
  }
}
