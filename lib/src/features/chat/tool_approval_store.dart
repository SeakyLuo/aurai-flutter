import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/tool_models.dart';

class ToolApprovalStore {
  late SharedPreferences _preferences;
  final Map<String, String> persistent = {};
  final Map<String, Map<String, String>> sessions = {};

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final saved = _preferences.getString('scoped_tool_approvals');
    if (saved != null)
      persistent.addAll(Map<String, String>.from(jsonDecode(saved) as Map));
    final savedSessions = _preferences.getString(
      'scoped_session_tool_approvals',
    );
    if (savedSessions != null) {
      (jsonDecode(savedSessions) as Map).forEach((key, value) {
        sessions[key as String] = Map<String, String>.from(value as Map);
      });
    }
  }

  String key(ToolCall call, String senderId, ToolDefinition definition) {
    final keys = call.arguments.keys.where((key) => key != 'offset').toList()
      ..sort();
    return jsonEncode([
      call.name,
      senderId,
      definition.authorizationScope ??
          (call.name == 'runSkill'
              ? null
              : {for (final key in keys) key: call.arguments[key]}),
      if (call.name == 'runSkill') ...[
        call.arguments['name'],
        call.arguments['revision'],
      ],
    ]);
  }

  bool allows(
    String conversation,
    ToolCall call,
    String senderId,
    ToolDefinition definition,
  ) =>
      persistent.containsKey(key(call, senderId, definition)) ||
      (sessions[conversation]?.containsKey(key(call, senderId, definition)) ??
          false);

  Future<void> grant(
    String conversation,
    ToolCall call,
    String label,
    String scope,
    String senderId,
    ToolDefinition definition,
  ) async {
    final approvalKey = key(call, senderId, definition);
    if (scope == 'session') {
      final updated = {
        ...sessions,
        conversation: {...?sessions[conversation], approvalKey: label},
      };
      if (!await _preferences.setString(
        'scoped_session_tool_approvals',
        jsonEncode(updated),
      )) {
        throw StateError('保存授权失败');
      }
      sessions[conversation] = updated[conversation]!;
    } else if (scope == 'always') {
      final updated = {...persistent, approvalKey: label};
      final updatedSessions = {
        for (final entry in sessions.entries)
          entry.key: {...entry.value}..remove(approvalKey),
      };
      if (!await _preferences.setString(
        'scoped_session_tool_approvals',
        jsonEncode(updatedSessions),
      )) {
        throw StateError('保存授权失败');
      }
      if (!await _preferences.setString(
        'scoped_tool_approvals',
        jsonEncode(updated),
      )) {
        throw StateError('保存授权失败');
      }
      persistent.addAll(updated);
      sessions
        ..clear()
        ..addAll(updatedSessions);
    }
  }

  Future<void> removeConversation(String conversation) async {
    final updated = {...sessions}..remove(conversation);
    if (!await _preferences.setString(
      'scoped_session_tool_approvals',
      jsonEncode(updated),
    )) {
      throw StateError('清理会话授权失败');
    }
    sessions.remove(conversation);
  }

  Future<void> revoke(String key, {String? conversation}) async {
    if (conversation != null) {
      final updated = {
        ...sessions,
        conversation: {...sessions[conversation]!}..remove(key),
      };
      if (!await _preferences.setString(
        'scoped_session_tool_approvals',
        jsonEncode(updated),
      )) {
        throw StateError('撤销授权失败');
      }
      sessions[conversation] = updated[conversation]!;
      return;
    }
    final updated = {...persistent}..remove(key);
    if (!await _preferences.setString(
      'scoped_tool_approvals',
      jsonEncode(updated),
    )) {
      throw StateError('撤销授权失败');
    }
    persistent.remove(key);
  }
}
