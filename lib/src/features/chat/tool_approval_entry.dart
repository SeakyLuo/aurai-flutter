import 'dart:convert';
import '../../domain/agent_models.dart';

class ToolApprovalEntry {
  ToolApprovalEntry(this.key, String label, this.conversation) {
    final parts = jsonDecode(key) as List;
    tool = parts[0] as String;
    sender = parts[1] as String;
    final value = parts[2];
    scope = value is String && value.startsWith('[') ? jsonDecode(value) : value;
    final separator = label.indexOf(' · ');
    savedSenderName = label.substring(0, separator);
    description = label.substring(separator + 3);
    skill = tool == 'runSkill' ? parts[3] as String : null;
    revision = tool == 'runSkill' ? parts[4].toString() : null;
  }
  final String key;
  final String? conversation;
  late final String tool, sender, savedSenderName, description;
  late final Object? scope;
  late final String? skill, revision;
  String get title => switch (tool) {
    'resumeGroupAutoReply' =>
      description.contains('触发思考') ? '恢复接话并触发思考' : '恢复接话',
    'pauseGroupAutoReply' => '暂停接话',
    'runSkill' => '运行技能',
    _ => toolTitle(tool),
  };
  Iterable<String> get references sync* {
    yield sender;
    if (conversation != null) yield conversation!;
    yield* _strings(scope);
  }

  Iterable<String> _strings(Object? value) sync* {
    if (value is String) yield value;
    if (value is List) {
      for (final child in value) {
        yield* _strings(child);
      }
    }
    if (value is Map) {
      for (final child in value.values) {
        yield* _strings(child);
      }
    }
  }

  String summary(Map<String, String> names) {
    if (skill != null) return '$skill · 版本 $revision';
    if (scope is List &&
        (scope as List).every((v) => v is String) &&
        (scope as List).isNotEmpty &&
        names.containsKey((scope as List).first)) {
      return (scope as List).map((v) => names[v] ?? '已移除的对象').join(' · ');
    }
    return description == title ? '' : description;
  }
}
