/// An opened, untouched direct-chat draft is not a history entry.
const emptyDirectConversation =
    "kind = 'direct' AND message_count = 0 AND title IN ('新对话', '新会话') "
    "AND draft = '' AND draft_quote_json IS NULL AND pending_goal IS NULL "
    'AND NOT EXISTS (SELECT 1 FROM attachments '
    'WHERE conversation_id = conversations.id)';

const visibleConversation = 'NOT ($emptyDirectConversation)';

/// Human-facing lists only contain conversations the local user participates in.
const localUserConversation =
    "id IN (SELECT conversation_id FROM conversation_members WHERE sender_id = 'user:local' AND left_at IS NULL)";
