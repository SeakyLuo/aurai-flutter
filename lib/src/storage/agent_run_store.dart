import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import '../domain/message_sender.dart';
import '../domain/model_provider.dart';
import '../domain/tool_models.dart';

class AgentRunStore {
  AgentRunStore(this.database);
  final Database database;

  Future<String> start(
    String conversationId,
    String userMessageId,
    ModelConfig config, {
    String senderId = 'agent:aurai',
    required String systemPrompt,
    required String customInstructions,
    required ResponsePreferences responsePreferences,
  }) async {
    final id = newMessageId();
    await database.transaction((txn) async {
      // Single chats have one implicit target; group targets are captured at send time.
      await txn.rawInsert(
        '''INSERT OR IGNORE INTO message_recipients (message_id, sender_id)
        SELECT m.id, c.default_sender_id FROM messages m
        INNER JOIN conversations c ON c.id = m.conversation_id
        WHERE m.id = ? AND c.id = ? AND c.kind = 'direct' AND m.role = 'user'
        AND NOT EXISTS (SELECT 1 FROM message_recipients WHERE message_id = m.id)
        ''',
        [userMessageId, conversationId],
      );
      final target = await txn.query(
        'message_recipients',
        where:
            'message_id = ? AND sender_id = ? AND message_id IN '
            '(SELECT id FROM messages WHERE conversation_id = ?)',
        whereArgs: [userMessageId, senderId, conversationId],
        limit: 1,
      );
      if (target.isEmpty) throw StateError('该 AI 不在这条消息的回复对象中');
      final senderRows = await txn.query(
        'message_senders',
        where: 'id = ?',
        whereArgs: [senderId],
        limit: 1,
      );
      final sender = MessageSender.fromRow(senderRows.single);
      await txn.insert('agent_runs', {
        'id': id,
        'conversation_id': conversationId,
        'user_message_id': userMessageId,
        'sender_id': senderId,
        'provider': config.service.name,
        'model': config.model,
        'configuration_json': jsonEncode({
          'senderName': sender.name,
          'provider': config.service.name,
          'model': config.model,
          'baseUrl': config.baseUrl,
          'systemPrompt': systemPrompt,
          'customInstructions': customInstructions,
          'responsePreferences': responsePreferences.toJson(),
        }),
        'status': 'running',
        'started_at': DateTime.now().microsecondsSinceEpoch,
      });
    });
    return id;
  }

  Future<String> startTurn(
    String conversationId,
    String runId,
    int ordinal,
  ) async {
    final id = newMessageId();
    await database.insert('model_turns', {
      'id': id,
      'conversation_id': conversationId,
      'run_id': runId,
      'ordinal': ordinal,
      'status': 'running',
      'started_at': DateTime.now().microsecondsSinceEpoch,
    });
    return id;
  }

  Future<void> finishTurn(String id, ModelTurn turn) async {
    await database.update(
      'model_turns',
      {
        'response_id': turn.continuationToken,
        'response_json': jsonEncode({
          'input': turn.requestInput,
          'output': turn.response['output'],
          'status': turn.response['status'],
          'incomplete_details': turn.response['incomplete_details'],
          'error': turn.response['error'],
        }),
        'status': turn.response['status'],
        'finished_at': DateTime.now().microsecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> startTool(
    String conversationId,
    String runId,
    String turnId,
    ToolCall call,
  ) async {
    await database.transaction((txn) async {
      final id = '$runId:${call.id}';
      await txn.insert('tool_calls', {
        'id': id,
        'conversation_id': conversationId,
        'run_id': runId,
        'model_turn_id': turnId,
        'provider_call_id': call.id,
        'name': call.name,
        'title': toolTitle(call.name),
        'arguments_json': jsonEncode(call.arguments),
        'status': 'running',
        'started_at': DateTime.now().microsecondsSinceEpoch,
      });
      await txn.insert('run_events', {
        'conversation_id': conversationId,
        'run_id': runId,
        'kind': 'tool',
        'tool_call_id': id,
      });
    });
  }

  Future<void> finishTool(String runId, ToolResult result) async {
    // Notification bodies and screen pixels remain task-scoped, not durable history.
    final output = result.toolName == 'getNotifications'
        ? <String, Object?>{'contentRetention': 'task_only'}
        : result.output;
    await database.update(
      'tool_calls',
      {
        'status': switch (result.status) {
          ToolResultStatus.success => 'completed',
          ToolResultStatus.cancelled => 'cancelled',
          ToolResultStatus.denied || ToolResultStatus.error => 'failed',
        },
        'result_status': result.status.name,
        'result_json': jsonEncode(output),
        'finished_at': DateTime.now().microsecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: ['$runId:${result.callId}'],
    );
  }

  Future<int> requestApproval(
    String runId,
    ToolCall call,
    ToolDefinition definition,
  ) => database.insert('tool_approvals', {
    'tool_call_id': '$runId:${call.id}',
    'safety': definition.safetyFor(call.arguments).name,
    'scope_json': jsonEncode(call.arguments),
    'decision': 'pending',
    'requested_at': DateTime.now().microsecondsSinceEpoch,
  });

  Future<void> resolveApproval(int id, bool approved) async {
    await database.update(
      'tool_approvals',
      {
        'decision': approved ? 'approved' : 'denied',
        'resolved_at': DateTime.now().microsecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> finish(
    String runId,
    String status,
    int elapsedMs, {
    String? finalMessageId,
    String? error,
    bool isTask = false,
  }) async {
    await database.transaction((txn) async {
      final batch = txn.batch();
      batch.update(
        'agent_runs',
        {
          'status': status,
          'elapsed_ms': elapsedMs,
          'finished_at': DateTime.now().microsecondsSinceEpoch,
          'final_message_id': finalMessageId,
          'error_detail': error,
          'is_task': isTask ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [runId],
      );
      batch.update(
        'conversations',
        {
          'run_state': status == 'completed' ? 'idle' : status,
          'error_detail': error,
          if (status == 'completed') 'pending_goal': null,
        },
        where: 'active_run_id = ?',
        whereArgs: [runId],
      );
      if (finalMessageId != null) {
        batch.update(
          'messages',
          {'kind': 'commentary'},
          where: 'run_id = ? AND id != ?',
          whereArgs: [runId, finalMessageId],
        );
        batch.update(
          'messages',
          {'kind': 'final'},
          where: 'id = ?',
          whereArgs: [finalMessageId],
        );
      }
      batch.update(
        'model_turns',
        {'status': status},
        where: 'run_id = ? AND status = ?',
        whereArgs: [runId, 'running'],
      );
      batch.update(
        'tool_calls',
        {'status': status == 'cancelled' ? 'cancelled' : 'failed'},
        where: 'run_id = ? AND status = ?',
        whereArgs: [runId, 'running'],
      );
      batch.update(
        'tool_approvals',
        {'decision': 'interrupted'},
        where:
            'decision = ? AND tool_call_id IN (SELECT id FROM tool_calls WHERE run_id = ?)',
        whereArgs: ['pending', runId],
      );
      await batch.commit(noResult: true);
    });
  }
}
