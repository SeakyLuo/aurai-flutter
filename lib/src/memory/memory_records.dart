part of 'memory_controller.dart';

Map<String, Object?> memoryRecord(Map<String, Object?> entry) => {
  'id': entry['id'],
  'text': entry['text'],
  'version': entry['version'],
  'kind': entry['kind'],
  'assertion': entry['assertion'],
  'state': entry['state'],
  'supersededBy': entry['superseded_by'],
  'keywords': jsonDecode(entry['keywords_json'] as String),
  'entities': jsonDecode(entry['entities_json'] as String),
  'manual': entry['manual'] == 1,
  'createdAt': localIsoTime(
    DateTime.fromMillisecondsSinceEpoch(
      entry['created_at'] as int,
      isUtc: true,
    ),
  ),
  'updatedAt': localIsoTime(
    DateTime.fromMillisecondsSinceEpoch(
      entry['updated_at'] as int,
      isUtc: true,
    ),
  ),
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
    int? expectedVersion,
    required int expectedRevision,
    required String conversationId,
    required String? messageId,
  }) async {
    if (expectedRevision != revision) throw StateError('记忆已变化，请重新查询后操作');
    if (operation != 'delete' &&
        (text!.trim().isEmpty || text.length > memoryTextLimit)) {
      throw StateError('请填写不超过2000字的记忆');
    }
    final original = id == null ? null : await readableMemory(id);
    if (id != null &&
        (original == null || original['version'] != expectedVersion)) {
      throw StateError('这条记忆已变化，请重新读取后操作');
    }
    _invalidate();
    final epoch = revision;
    final recordId = id ?? newMessageId();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _commitRecords((txn) async {
      if (epoch != revision) throw StateError('记忆已变化，请重新查询后操作');
      if (operation == 'delete') {
        final rows = await txn.query(
          'user_memories',
          columns: ['version'],
          where: 'id = ? AND $_scopeWhere',
          whereArgs: [recordId, ..._scopeArgs],
          limit: 1,
        );
        if (rows.isEmpty || rows.single['version'] != expectedVersion)
          throw StateError('记忆已变化，请重新读取后操作');
        await _deleteMemory(txn, recordId);
      } else if (operation == 'create') {
        await txn.insert('user_memories', {
          'id': recordId,
          'owner_id': ownerId,
          'memory_scope': scope,
          'text': text!.trim(),
          ...memorySearchColumns(text.trim()),
          'manual': 1,
          'source_conversation_id': conversationId,
          'source_message_id': messageId,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        final changed = await txn.update(
          'user_memories',
          {
            'text': text!.trim(),
            'manual': 1,
            'updated_at': now,
            'version': expectedVersion! + 1,
            ...memorySearchColumns(text.trim()),
          },
          where: "id = ? AND $_scopeWhere AND version = ? AND state = 'active'",
          whereArgs: [recordId, ..._scopeArgs, expectedVersion],
        );
        if (changed != 1) throw StateError('记忆已变化，请重新查询后操作');
      }
      if (operation != 'delete' && messageId != null) {
        await txn.insert('memory_sources', {
          'memory_id': recordId,
          'source_key': 'message:$messageId',
          'conversation_id': conversationId,
          'message_id': messageId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    return operation == 'delete'
        ? {'deleted': true}
        : {
            'saved': true,
            'memory': memoryRecord((await readableMemory(recordId))!),
          };
  }
}
