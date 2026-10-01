const groupMuteColumn =
    'ALTER TABLE conversation_members ADD COLUMN muted_until INTEGER NOT NULL DEFAULT 0';

const groupWideMuteColumn =
    'ALTER TABLE conversations ADD COLUMN group_muted_until INTEGER NOT NULL DEFAULT 0';

String effectiveGroupMuteSql(String member) {
  final group =
      '(SELECT group_muted_until FROM conversations WHERE id = $member.conversation_id)';
  return "CASE WHEN $member.muted_until = -1 THEN -1 "
      "WHEN $member.role = 'member' AND $group = -1 THEN -1 "
      "WHEN $member.role = 'member' THEN MAX($member.muted_until, $group) "
      'ELSE $member.muted_until END';
}

// Enforce publication atomically; existing transcript and private execution
// records can still be persisted after a member is muted.
const groupMuteMessageTrigger = '''
CREATE TRIGGER group_mute_message BEFORE INSERT ON messages
WHEN NEW.kind IN ('user', 'group_message', 'html_game', 'quick_reply')
AND NOT EXISTS (SELECT 1 FROM messages WHERE id = NEW.id)
AND EXISTS (SELECT 1 FROM conversations WHERE id = NEW.conversation_id AND kind = 'group')
AND EXISTS (SELECT 1 FROM conversation_members
  WHERE conversation_id = NEW.conversation_id AND sender_id = NEW.sender_id
  AND left_at IS NULL AND ((muted_until = -1 OR muted_until > CAST((julianday('now') - 2440587.5) * 86400000000 AS INTEGER))
  OR (role = 'member' AND EXISTS (SELECT 1 FROM conversations WHERE id = NEW.conversation_id
    AND (group_muted_until = -1 OR group_muted_until > CAST((julianday('now') - 2440587.5) * 86400000000 AS INTEGER))))))
BEGIN
  SELECT RAISE(ABORT, '你已被禁言，暂时不能在这个群发送消息');
END
''';
