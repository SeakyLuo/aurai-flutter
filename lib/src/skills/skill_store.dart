import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedSkill {
  const SavedSkill({
    required this.name,
    required this.description,
    required this.instructions,
    required this.script,
    required this.enabled,
    required this.revision,
  });
  final String name, description, instructions, script;
  final bool enabled;
  final int revision;
  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'instructions': instructions,
    'script': script,
    'enabled': enabled,
    'revision': revision,
  };
  factory SavedSkill.fromJson(Map<String, Object?> data) => SavedSkill(
    name: data['name'] as String,
    description: data['description'] as String,
    instructions: data['instructions'] as String,
    script: data['script'] as String,
    enabled: data['enabled'] as bool,
    revision: data['revision'] as int,
  );
}

class SkillStore extends ChangeNotifier {
  final _preferences = SharedPreferencesAsync();
  final Map<String, SavedSkill> _skills = {};
  Future<void> _pending = Future.value();
  List<SavedSkill> get skills => List.unmodifiable(_skills.values);

  Future<void> initialize() async {
    final raw = await _preferences.getString('saved_skills');
    if (raw == null) return;
    for (final value in jsonDecode(raw) as List) {
      final skill = SavedSkill.fromJson((value as Map).cast<String, Object?>());
      _skills[skill.name] = skill;
    }
  }

  SavedSkill read(String name) {
    final skill = _skills[name];
    if (skill == null) throw StateError('技能不存在，请重新查看技能列表');
    return skill;
  }

  Future<void> save(SavedSkill value, {String? previousName}) =>
      _enqueue(() async {
        final name = value.name.trim();
        if (name.isEmpty ||
            name.length > 60 ||
            value.description.trim().isEmpty ||
            value.description.length > 300 ||
            value.instructions.trim().isEmpty ||
            value.instructions.length > 12000 ||
            value.script.length > 15000) {
          throw StateError('请填写名称、简介和使用说明，并检查内容长度');
        }
        final old = previousName == null ? null : read(previousName);
        if (old != null && old.revision != value.revision) {
          throw StateError('技能已被修改，请重新打开后编辑');
        }
        if (_skills.containsKey(name) && name != previousName) {
          throw StateError('已存在同名技能，请换一个名称');
        }
        final next = Map<String, SavedSkill>.of(_skills);
        if (previousName != null) next.remove(previousName);
        next[name] = SavedSkill(
          name: name,
          description: value.description.trim(),
          instructions: value.instructions.trim(),
          script: value.script,
          enabled: value.enabled,
          revision: (old?.revision ?? 0) + 1,
        );
        await _commit(next);
      });

  Future<void> delete(String name) => _enqueue(() async {
    read(name);
    await _commit(Map.of(_skills)..remove(name));
  });

  Future<void> _commit(Map<String, SavedSkill> next) async {
    await _preferences.setString(
      'saved_skills',
      jsonEncode(next.values.map((skill) => skill.toJson()).toList()),
    );
    _skills
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.catchError((Object error) {});
    return result;
  }
}
