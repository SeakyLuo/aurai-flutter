import 'group_chat_store.dart';
import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:sqflite/sqflite.dart';

import '../features/chat/conversation.dart';
import 'conversation_rows.dart';
import 'group_unread_messages.dart';

enum ProjectLocation { external, managed }

enum ProjectMemoryMode { shared, projectOnly }

const projectNameMaxLength = 40;
const projectInstructionsMaxLength = 10000;

void validateProjectName(String name) {
  if (name.isEmpty) throw StateError('请填写项目名称');
  if (name.characters.length > projectNameMaxLength) {
    throw StateError('项目名称不能超过 $projectNameMaxLength 个字');
  }
}

class DevelopmentProject {
  const DevelopmentProject({
    required this.id,
    required this.name,
    this.description = '',
    this.instructions = '',
    required this.icon,
    required this.iconColor,
    required this.rootUri,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
    this.pinned = false,
    this.memoryMode = ProjectMemoryMode.shared,
    this.defaultSenderId = 'agent:aurai',
    this.gitRemoteUrl = '',
    this.worktreeId,
    this.worktreeName,
    this.worktreeDeleted = false,
  });

  final String id;
  final String name;
  final String description;
  final String instructions;
  final String icon;
  final String iconColor;
  final String rootUri;
  final ProjectLocation location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  final bool pinned;
  final ProjectMemoryMode memoryMode;
  final String defaultSenderId;
  final String gitRemoteUrl;
  final String? worktreeId, worktreeName;
  final bool worktreeDeleted;
  String get workspaceId => worktreeId ?? id;

  DevelopmentProject inWorktree(
    String workspace,
    String label, {
    bool deleted = false,
  }) => DevelopmentProject(
    id: id,
    name: name,
    description: description,
    instructions: instructions,
    icon: icon,
    iconColor: iconColor,
    rootUri: 'aurai://project/$workspace',
    location: location,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archived: archived,
    pinned: pinned,
    memoryMode: memoryMode,
    defaultSenderId: defaultSenderId,
    gitRemoteUrl: gitRemoteUrl,
    worktreeId: workspace,
    worktreeName: label,
    worktreeDeleted: deleted,
  );

  factory DevelopmentProject.fromRow(
    Map<String, Object?> row,
  ) => DevelopmentProject(
    id: row['id'] as String,
    name: row['name'] as String,
    description: row['description'] as String,
    instructions: row['instructions'] as String,
    icon: row['icon'] as String,
    iconColor: row['icon_color'] as String,
    rootUri: row['root_uri'] as String,
    location: ProjectLocation.values.byName(row['location'] as String),
    createdAt: DateTime.fromMicrosecondsSinceEpoch(row['created_at'] as int),
    updatedAt: DateTime.fromMicrosecondsSinceEpoch(row['updated_at'] as int),
    archived: row['archived'] == 1,
    pinned: row['pinned'] == 1,
    memoryMode: ProjectMemoryMode.values.byName(row['memory_mode'] as String),
    defaultSenderId: row['default_sender_id'] as String,
    gitRemoteUrl: row['git_remote_url'] as String,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'description': description,
    'instructions': instructions,
    'icon': icon,
    'icon_color': iconColor,
    'root_uri': rootUri,
    'location': location.name,
    'created_at': createdAt.microsecondsSinceEpoch,
    'updated_at': updatedAt.microsecondsSinceEpoch,
    'archived': archived ? 1 : 0,
    'pinned': pinned ? 1 : 0,
    'memory_mode': memoryMode.name,
    'default_sender_id': defaultSenderId,
    'git_remote_url': gitRemoteUrl,
  };
}

class DevelopmentProjects {
  const DevelopmentProjects(this.database);
  final Database database;
  static final changingWorktrees = <String>{};
  static int worktreeRevision = 0;

  Future<void> bindWorktree(
    String conversationId,
    DevelopmentProject project,
  ) async {
    if (project.worktreeId == null) {
      await unbindConversationWorktree(conversationId);
      return;
    }
    await database.insert('app_state', {
      'key': 'conversation_worktree:$conversationId',
      'value': jsonEncode({
        'projectId': project.id,
        'id': project.worktreeId,
        'name': project.worktreeName,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    worktreeRevision++;
  }

  Future<void> markWorktreeDeleted(String id) async {
    await database.rawUpdate(
      "UPDATE app_state SET value = json_set(value, '\$.deleted', 1) "
      "WHERE key LIKE 'conversation_worktree:%' AND json_extract(value, '\$.id') = ?",
      [id],
    );
    worktreeRevision++;
  }

  Future<void> unbindConversationWorktree(String id) async {
    await database.delete(
      'app_state',
      where: 'key = ?',
      whereArgs: ['conversation_worktree:$id'],
    );
    worktreeRevision++;
  }

  Future<DevelopmentProject> forConversation(
    String projectId,
    String conversationId,
  ) async {
    final results = await Future.wait([
      database.query(
        'development_projects',
        where: 'id = ?',
        whereArgs: [projectId],
      ),
      database.query(
        'app_state',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['conversation_worktree:$conversationId'],
      ),
    ]);
    final project = DevelopmentProject.fromRow(results[0].single);
    if (results[1].isEmpty) return project;
    final binding = jsonDecode(results[1].single['value'] as String) as Map;
    if (binding['projectId'] != projectId) throw StateError('会话的工作树与所属项目不一致');
    return project.inWorktree(
      binding['id'] as String,
      binding['name'] as String,
      deleted: binding['deleted'] == 1,
    );
  }

  Future<List<DevelopmentProject>> list() async => (await database.query(
    'development_projects',
    where: 'archived = 0',
    orderBy: 'pinned DESC, updated_at DESC, id DESC',
  )).map(DevelopmentProject.fromRow).toList();

  Future<DevelopmentProject> read(String id) async =>
      DevelopmentProject.fromRow(
        (await database.query(
          'development_projects',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        )).single,
      );

  Future<void> create(DevelopmentProject project) {
    validateProjectName(project.name);
    return database.insert('development_projects', project.toRow());
  }

  Future<void> rename(String id, String name) {
    validateProjectName(name);
    return database.update(
      'development_projects',
      {'name': name, 'updated_at': DateTime.now().microsecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setIcon(String id, String icon, String iconColor) =>
      database.update(
        'development_projects',
        {
          'icon': icon,
          'icon_color': iconColor,
          'updated_at': DateTime.now().microsecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> updateProfile(
    String id, {
    required String name,
    required String description,
    required String icon,
    required String iconColor,
    required String gitRemoteUrl,
  }) {
    validateProjectName(name);
    return database.update(
      'development_projects',
      {
        'name': name,
        'description': description,
        'icon': icon,
        'icon_color': iconColor,
        'git_remote_url': gitRemoteUrl,
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setPinned(String id, bool pinned) => database.update(
    'development_projects',
    {'pinned': pinned ? 1 : 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> setMemoryMode(String id, ProjectMemoryMode mode) =>
      database.update(
        'development_projects',
        {'memory_mode': mode.name},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> setInstructions(String id, String instructions) {
    if (instructions.characters.length > projectInstructionsMaxLength) {
      throw StateError('项目自定义指令不能超过 $projectInstructionsMaxLength 个字');
    }
    return database.update(
      'development_projects',
      {
        'instructions': instructions,
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setDefaultSender(String id, String senderId) => database.update(
    'development_projects',
    {'default_sender_id': senderId},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> remove(String id) async {
    await database.transaction((txn) async {
      await txn.delete(
        'user_memories',
        where: 'owner_id = ?',
        whereArgs: ['project:$id'],
      );
      await txn.update(
        'conversations',
        {'project_id': null},
        where: 'project_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'development_projects',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> markAllRead(String id) async {
    final results = await Future.wait([
      database.query(
        'conversations',
        columns: ['id', 'active_run_id'],
        where:
            "project_id = ? AND kind = 'direct' AND active_run_id IS NOT NULL",
        whereArgs: [id],
      ),
      database.rawQuery(
        '''SELECT c.id AS conversation_id, m.created_at, m.id AS message_id
        FROM conversations c
        INNER JOIN messages m ON m.id = (
          SELECT latest.id FROM messages latest
          WHERE latest.conversation_id = c.id
          ORDER BY latest.created_at DESC, latest.id DESC
          LIMIT 1
        )
        WHERE c.project_id = ? AND c.kind = 'group' ''',
        [id],
      ),
    ]);
    final batch = database.batch();
    for (final row in results[0]) {
      batch.insert('app_state', {
        'key': 'seen_run:${row['id']}',
        'value': row['active_run_id'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final row in results[1]) {
      batch.insert('app_state', {
        'key': 'group_read:${row['conversation_id']}',
        'value': jsonEncode({'at': row['created_at'], 'id': row['message_id']}),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Set<String>> unreadProjectIds(List<String> projectIds) async {
    if (projectIds.isEmpty) return {};
    final placeholders = List.filled(projectIds.length, '?').join(',');
    final results = await Future.wait([
      database.rawQuery('''SELECT DISTINCT c.project_id
        FROM conversations c
        WHERE c.project_id IN ($placeholders)
          AND c.archived = 0
          AND c.kind = 'direct'
          AND c.run_state = 'idle'
          AND c.active_run_id IS NOT NULL
          AND c.pending_goal IS NULL
          AND EXISTS (
            SELECT 1 FROM conversation_members member
            WHERE member.conversation_id = c.id
              AND member.sender_id = 'user:local'
              AND member.left_at IS NULL
          )
          AND NOT EXISTS (
            SELECT 1 FROM app_state seen
            WHERE seen.key = 'seen_run:' || c.id
              AND seen.value = c.active_run_id
          )''', projectIds),
      database.rawQuery(
        '''SELECT DISTINCT c.project_id
        FROM conversations c
        LEFT JOIN app_state read_state
          ON read_state.key = 'group_read:' || c.id
        WHERE c.project_id IN ($placeholders)
          AND c.archived = 0
          AND c.kind = 'group'
          AND EXISTS (
            SELECT 1 FROM conversation_members member
            WHERE member.conversation_id = c.id
              AND member.sender_id = 'user:local'
              AND member.left_at IS NULL
          )
          AND EXISTS (
            SELECT 1 FROM messages message
            WHERE message.conversation_id = c.id
              AND message.sender_id != 'user:local'
              AND message.role = 'assistant'
              AND message.kind NOT IN ('commentary', 'system')
              AND (
                message.interactive_json IS NULL
                OR json_extract(message.interactive_json, '\$.participation.audience') IS NULL
                OR EXISTS (
                  SELECT 1 FROM json_each(
                    message.interactive_json,
                    '\$.participation.audience'
                  )
                  WHERE value = 'user:local'
                )
              )
              AND (
                message.created_at > COALESCE(
                  json_extract(read_state.value, '\$.at'),
                  CAST((SELECT value FROM app_state WHERE key = ?) AS INTEGER)
                )
                OR (
                  message.created_at = COALESCE(
                    json_extract(read_state.value, '\$.at'),
                    CAST((SELECT value FROM app_state WHERE key = ?) AS INTEGER)
                  )
                  AND message.id > COALESCE(
                    json_extract(read_state.value, '\$.id'),
                    ''
                  )
                )
              )
          )''',
        [
          ...projectIds,
          GroupUnreadMessages.baselineKey,
          GroupUnreadMessages.baselineKey,
        ],
      ),
    ]);
    return {
      for (final rows in results)
        for (final row in rows) row['project_id'] as String,
    };
  }

  Future<void> assignConversation(
    String conversationId,
    String? projectId, {
    String actorId = 'user:local',
  }) => database.transaction((txn) async {
    final rows = await txn.query(
      'conversations',
      columns: ['kind', 'project_id'],
      where: 'id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    if (rows.single['kind'] == 'group') {
      await GroupChatStore(
        database,
      ).requireManager(txn, conversationId, actorId);
    }
    if (rows.single['project_id'] != projectId) {
      await txn.delete(
        'app_state',
        where: 'key = ?',
        whereArgs: ['conversation_worktree:$conversationId'],
      );
    }
    await txn.update(
      'conversations',
      {'project_id': projectId},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    if (projectId != null) {
      await txn.update(
        'development_projects',
        {'updated_at': DateTime.now().microsecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [projectId],
      );
    }
  });

  Future<List<Conversation>> conversations(String projectId) async =>
      (await database.query(
        'conversations',
        where: 'project_id = ? AND archived = 0',
        whereArgs: [projectId],
        orderBy: 'pinned DESC, updated_at DESC, id DESC',
      )).map(conversationFromRow).toList();
}
