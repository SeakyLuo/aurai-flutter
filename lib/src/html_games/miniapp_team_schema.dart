const miniappTeamSchema = [
  '''CREATE TABLE miniapp_developers (
    app_id TEXT NOT NULL REFERENCES html_apps(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL REFERENCES message_senders(id) ON DELETE CASCADE,
    added_at INTEGER NOT NULL,
    PRIMARY KEY (app_id, sender_id)
  )''',
  'CREATE INDEX miniapp_developers_sender ON miniapp_developers(sender_id, app_id)',
  '''CREATE TABLE miniapp_edit_requests (
    app_id TEXT NOT NULL REFERENCES html_apps(id) ON DELETE CASCADE,
    sender_id TEXT NOT NULL REFERENCES message_senders(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('pending', 'approved', 'rejected', 'cancelled')),
    requested_at INTEGER NOT NULL,
    reviewed_by TEXT REFERENCES message_senders(id),
    PRIMARY KEY (app_id, sender_id)
  )''',
  'CREATE INDEX miniapp_requests_status ON miniapp_edit_requests(status, requested_at, app_id, sender_id)',
];
