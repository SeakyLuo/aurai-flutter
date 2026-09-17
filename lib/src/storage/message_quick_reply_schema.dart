const messageQuickReplySchema = [
  '''CREATE TABLE message_quick_replies (
    message_id TEXT PRIMARY KEY REFERENCES messages(id) ON DELETE CASCADE,
    parent_message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    actor_id TEXT NOT NULL REFERENCES message_senders(id),
    reply_key TEXT NOT NULL,
    UNIQUE(parent_message_id, actor_id)
  )''',
  'CREATE INDEX message_quick_reply_parent ON message_quick_replies(parent_message_id, message_id)',
];
