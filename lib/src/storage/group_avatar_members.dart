part of 'group_chat_store.dart';

extension GroupAvatarMembers on GroupChatStore {
  Future<Map<String, List<MessageSender>>> _avatarMembers(
    List<String> groupIds,
  ) async {
    if (groupIds.isEmpty) return {};
    final (_, rows) = await (
      GroupAvatarStore.load(database, groupIds),
      database.rawQuery('''
      SELECT conversation_id, sender_id FROM (
        SELECT conversation_id, sender_id,
          ROW_NUMBER() OVER (PARTITION BY conversation_id ORDER BY position, sender_id) AS member_rank
        FROM conversation_members
        WHERE conversation_id IN (${_slots(groupIds.length)}) AND left_at IS NULL
      ) WHERE member_rank <= 9 ORDER BY conversation_id, member_rank
    ''', groupIds),
    ).wait;
    if (rows.isEmpty) return {};
    final senders = await _senders(
      database,
      rows.map((row) => row['sender_id'] as String).toSet().toList(),
    );
    final result = <String, List<MessageSender>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row['conversation_id'] as String, () => [])
          .add(senders[row['sender_id']]!);
    }
    return result;
  }
}
