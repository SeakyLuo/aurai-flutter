/// An opened, untouched direct-chat draft is not a history entry.
const emptyDirectConversation =
    "kind = 'direct' AND message_count = 0 "
    "AND draft = '' AND draft_quote_json IS NULL AND pending_goal IS NULL "
    'AND NOT EXISTS (SELECT 1 FROM attachments '
    'WHERE conversation_id = conversations.id)';

const visibleConversation = 'NOT ($emptyDirectConversation)';
