import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/tool_models.dart';

class ToolApprovalStore {
  late SharedPreferences _preferences;
  final Map<String, String> persistent = {};
  final Map<String, Map<String, String>> sessions = {};

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final saved = _preferences.getString('tool_approvals');
    if (saved != null)
      persistent.addAll(Map<String, String>.from(jsonDecode(saved) as Map));
    final savedSessions = _preferences.getString('session_tool_approvals');
    if (savedSessions != null) {
      (jsonDecode(savedSessions) as Map).forEach((key, value) {
        sessions[key as String] = Map<String, String>.from(value as Map);
      });
    }
  }

  String key(ToolCall call) => call.name == 'runSkill'
      ? jsonEncode([
          call.name,
          call.arguments['name'],
          call.arguments['revision'],
        ])
      : call.name;

  bool allows(String conversation, ToolCall call) =>
      persistent.containsKey(key(call)) ||
      (sessions[conversation]?.containsKey(key(call)) ?? false);

  Future<void> grant(
    String conversation,
    ToolCall call,
    String label,
    String scope,
  ) async {
    if (scope == 'session') {
      final updated = {
        ...sessions,
        conversation: {...?sessions[conversation], key(call): label},
      };
      if (!await _preferences.setString(
        'session_tool_approvals',
        jsonEncode(updated),
      )) {
        throw StateError('保存授权失败');
      }
      sessions[conversation] = updated[conversation]!;
    } else if (scope == 'always') {
      final updated = {...persistent, key(call): label};
      if (!await _preferences.setString(
        'tool_approvals',
        jsonEncode(updated),
      )) {
        throw StateError('保存授权失败');
      }
      persistent.addAll(updated);
    }
  }

  Future<void> removeConversation(String conversation) async {
    final updated = {...sessions}..remove(conversation);
    if (!await _preferences.setString(
      'session_tool_approvals',
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
        'session_tool_approvals',
        jsonEncode(updated),
      )) {
        throw StateError('撤销授权失败');
      }
      sessions[conversation] = updated[conversation]!;
      return;
    }
    final updated = {...persistent}..remove(key);
    if (!await _preferences.setString('tool_approvals', jsonEncode(updated))) {
      throw StateError('撤销授权失败');
    }
    persistent.remove(key);
  }
}
