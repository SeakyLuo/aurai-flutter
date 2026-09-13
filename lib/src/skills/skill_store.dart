import 'skill_icon_names.dart';
import 'skill_sort.dart';
import 'skill_permission.dart';
import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedSkill {
  const SavedSkill({
    this.id = '',
    this.dependencyIds = const [],
    required this.name,
    required this.description,
    required this.instructions,
    required this.script,
    required this.enabled,
    required this.revision,
    this.icon = 'skill',
  });
  final String id, name, description, instructions, script;
  final List<String> dependencyIds;
  final String icon;
  final bool enabled;
  final int revision;
  Map<String, Object?> toJson() => {
    'id': id,
    'dependencyIds': dependencyIds,
    'name': name,
    'description': description,
    'instructions': instructions,
    'script': script,
    'enabled': enabled,
    'revision': revision,
    'icon': icon,
  };
  factory SavedSkill.fromJson(Map<String, Object?> data) => SavedSkill(
    id: data['id'] as String? ?? '',
    dependencyIds: List<String>.from(
      data['dependencyIds'] as List? ?? const [],
    ),
    name: data['name'] as String,
    description: data['description'] as String,
    instructions: data['instructions'] as String,
    script: data['script'] as String,
    enabled: data['enabled'] as bool,
    revision: data['revision'] as int,
    icon: data['icon'] as String? ?? 'skill',
  );
}

class SkillStore extends ChangeNotifier {
  final _preferences = SharedPreferencesAsync();
  final Map<String, SavedSkill> _skills = {};
  final Map<String, SkillPermission> _permissions = {};
  final Map<String, Map<String, int>> _statistics = {};
  SkillSort sort = SkillSort.createdDescending;

  DateTime? createdAt(String id) => _statisticTime(id, 'created');
  DateTime? updatedAt(String id) => _statisticTime(id, 'updated');
  int useCount(String id) => _statistics[id]?['uses'] ?? 0;

  DateTime? _statisticTime(String id, String field) {
    final value = _statistics[id]?[field];
    return value == null ? null : DateTime.fromMicrosecondsSinceEpoch(value);
  }

  Future<void> saveSort(SkillSort value) => _enqueue(() async {
    await _database.insert('app_state', {
      'key': 'skill_sort',
      'value': value.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    sort = value;
    notifyListeners();
  });

  int compareSkills(SavedSkill a, SavedSkill b) {
    final first =
        _statistics[a.id]?[sort.field] ?? (sort.field == 'uses' ? 0 : null);
    final second =
        _statistics[b.id]?[sort.field] ?? (sort.field == 'uses' ? 0 : null);
    if (first == null && second != null) return 1;
    if (first != null && second == null) return -1;
    final comparison = first == null ? 0 : first.compareTo(second!);
    if (comparison != 0) return sort.descending ? -comparison : comparison;
    final byName = a.name.compareTo(b.name);
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  Future<void> recordUse(String id) => _enqueue(() async {
    if (!_skills.containsKey(id)) return;
    final stats = {
      ...?_statistics[id],
      'uses': (_statistics[id]?['uses'] ?? 0) + 1,
    };
    await _database.insert('app_state', {
      'key': 'skill_statistics',
      'value': jsonEncode({..._statistics, id: stats}),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _statistics[id] = stats;
    notifyListeners();
  });

  SkillPermission permissionFor(String id) =>
      _permissions[id] ?? defaultPermission;
  SkillPermission? permissionOverrideFor(String id) => _permissions[id];
  SkillPermission defaultPermission = SkillPermission.lowRisk;

  Future<void> saveDefaultPermission(SkillPermission permission) =>
      _enqueue(() async {
        await _database.insert('app_state', {
          'key': 'skill_default_permission',
          'value': permission.name,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        defaultPermission = permission;
        notifyListeners();
      });
  late Database _database;
  Future<void> _pending = Future.value();
  List<SavedSkill> get skills => List.unmodifiable(_skills.values);
  String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> initialize(Database database) async {
    _database = database;
    final migrated = await database.query(
      'app_state',
      where: 'key = ?',
      whereArgs: ['skills_migrated'],
    );
    if (migrated.isEmpty) {
      final raw = await _preferences.getString('saved_skills');
      final legacy = raw == null
          ? <SavedSkill>[]
          : [
              for (final value in jsonDecode(raw) as List)
                SavedSkill.fromJson((value as Map).cast<String, Object?>()),
            ];
      await database.transaction((txn) async {
        final batch = txn.batch();
        for (final skill in legacy) {
          batch.insert('skills', {..._row(skill), 'id': _newId()});
        }
        batch.insert('app_state', {'key': 'skills_migrated', 'value': '1'});
        await batch.commit(noResult: true);
      });
    }
    await _preferences.remove('saved_skills');
    final rows = await Future.wait([
      database.query('skills'),
      database.query('skill_dependencies'),
      database.query(
        'app_state',
        where: 'key IN (?, ?, ?, ?)',
        whereArgs: [
          'skill_permissions',
          'skill_default_permission',
          'skill_statistics',
          'skill_sort',
        ],
      ),
    ]);
    for (final row in rows[2]) {
      if (row['key'] == 'skill_sort') {
        sort = SkillSort.values.byName(row['value'] as String);
      } else if (row['key'] == 'skill_statistics') {
        final stored = jsonDecode(row['value'] as String) as Map;
        for (final entry in stored.entries) {
          _statistics[entry.key as String] = Map<String, int>.from(
            entry.value as Map,
          );
        }
      } else if (row['key'] == 'skill_default_permission') {
        defaultPermission = SkillPermission.values.byName(
          row['value'] as String,
        );
      } else {
        final permissions =
            jsonDecode(row['value'] as String) as Map<String, dynamic>;
        for (final entry in permissions.entries) {
          _permissions[entry.key] = SkillPermission.values.byName(
            entry.value as String,
          );
        }
      }
    }
    final dependencies = <String, List<String>>{};
    for (final row in rows[1]) {
      dependencies
          .putIfAbsent(row['skill_id'] as String, () => [])
          .add(row['dependency_id'] as String);
    }
    for (final row in rows[0]) {
      final skill = SavedSkill.fromJson({
        ...row,
        'enabled': row['enabled'] == 1,
        'dependencyIds': List<String>.unmodifiable(
          dependencies[row['id']] ?? <String>[],
        ),
      });
      _skills[skill.id] = skill;
    }
  }

  SavedSkill read(String name) => _skills.values.firstWhere(
    (skill) => skill.name == name,
    orElse: () => throw StateError('技能不存在，请重新查看技能列表'),
  );
  SavedSkill readId(String id) {
    final skill = _skills[id];
    if (skill == null) throw StateError('依赖技能不存在，请重新选择');
    return skill;
  }

  List<SavedSkill> resolvedDependencies(SavedSkill root) {
    final found = <String, SavedSkill>{};
    void visit(SavedSkill skill) {
      if (!skill.enabled) throw StateError('技能“${skill.name}”已停用');
      if (found.containsKey(skill.id)) return;
      found[skill.id] = skill;
      for (final id in skill.dependencyIds) {
        visit(readId(id));
      }
    }

    visit(root);
    return found.values.toList();
  }

  void _validateGraph(Map<String, SavedSkill> graph) {
    final visiting = <String>{}, visited = <String>{};
    void visit(String id) {
      if (visiting.contains(id)) throw StateError('技能依赖不能形成循环');
      if (visited.contains(id)) return;
      final skill = graph[id];
      if (skill == null) throw StateError('依赖技能不存在，请重新选择');
      visiting.add(id);
      for (final dependency in skill.dependencyIds) {
        visit(dependency);
      }
      visiting.remove(id);
      visited.add(id);
    }

    for (final id in graph.keys) {
      visit(id);
    }
  }

  Future<void> save(
    SavedSkill value, {
    String? previousName,
    SkillPermission? permission,
    bool updatePermission = false,
  }) => _enqueue(() async {
    final name = value.name.trim();
    if (!skillIcons.containsKey(value.icon)) throw StateError('请选择有效的技能图标');
    if (name.isEmpty ||
        name.length > 60 ||
        value.description.trim().isEmpty ||
        value.description.length > 300 ||
        value.instructions.trim().isEmpty ||
        value.instructions.length > 10000 ||
        value.script.length > 50000) {
      throw StateError('请填写名称、简介和使用说明，并检查内容长度');
    }
    final old = previousName == null ? null : read(previousName);
    if (old != null && old.revision != value.revision)
      throw StateError('技能已被修改，请重新打开后编辑');
    if (_skills.values.any((s) => s.name == name && s.id != old?.id))
      throw StateError('已存在同名技能，请换一个名称');
    final saved = SavedSkill(
      id: old?.id ?? _newId(),
      name: name,
      description: value.description.trim(),
      instructions: value.instructions.trim(),
      script: value.script,
      icon: value.icon,
      enabled: value.enabled,
      revision: (old?.revision ?? 0) + 1,
      dependencyIds: List.unmodifiable(value.dependencyIds.toSet()),
    );
    _validateGraph({..._skills, saved.id: saved});
    final now = DateTime.now().microsecondsSinceEpoch;
    final statistics = {
      ...?_statistics[saved.id],
      if (old == null) 'created': now,
      'updated': now,
    };
    final nextPermissions = Map<String, SkillPermission>.of(_permissions);
    final contentChanged =
        old != null &&
        (old.script != saved.script ||
            old.instructions != saved.instructions ||
            !setEquals(old.dependencyIds.toSet(), saved.dependencyIds.toSet()));
    if (updatePermission) {
      if (permission == null) {
        nextPermissions.remove(saved.id);
      } else {
        nextPermissions[saved.id] = permission;
      }
    } else if (contentChanged &&
        permissionFor(saved.id) == SkillPermission.all) {
      nextPermissions[saved.id] = SkillPermission.lowRisk;
    }

    await _database.transaction((txn) async {
      await txn.insert('app_state', {
        'key': 'skill_statistics',
        'value': jsonEncode({..._statistics, saved.id: statistics}),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (old == null) {
        await txn.insert('skills', _row(saved));
      } else {
        await txn.update(
          'skills',
          _row(saved),
          where: 'id = ?',
          whereArgs: [saved.id],
        );
      }
      await txn.insert('app_state', {
        'key': 'skill_permissions',
        'value': jsonEncode(
          nextPermissions.map((id, value) => MapEntry(id, value.name)),
        ),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final batch = txn.batch();
      batch.delete(
        'skill_dependencies',
        where: 'skill_id = ?',
        whereArgs: [saved.id],
      );
      for (final id in saved.dependencyIds) {
        batch.insert('skill_dependencies', {
          'skill_id': saved.id,
          'dependency_id': id,
        });
      }
      await batch.commit(noResult: true);
    });
    _permissions
      ..clear()
      ..addAll(nextPermissions);
    _statistics[saved.id] = statistics;
    _skills[saved.id] = saved;
    notifyListeners();
  });

  Future<void> delete(String name) => _enqueue(() async {
    final skill = read(name);
    final users = _skills.values
        .where((s) => s.dependencyIds.contains(skill.id))
        .map((s) => s.name)
        .toList();
    if (users.isNotEmpty) throw StateError('“${users.join('、')}”依赖此技能，请先移除依赖');
    final nextPermissions = Map<String, SkillPermission>.of(_permissions)
      ..remove(skill.id);
    await _database.transaction((txn) async {
      await txn.delete('skills', where: 'id = ?', whereArgs: [skill.id]);
      await txn.insert('app_state', {
        'key': 'skill_statistics',
        'value': jsonEncode(Map.of(_statistics)..remove(skill.id)),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('app_state', {
        'key': 'skill_permissions',
        'value': jsonEncode(
          nextPermissions.map((id, value) => MapEntry(id, value.name)),
        ),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    _permissions.remove(skill.id);
    _statistics.remove(skill.id);
    _skills.remove(skill.id);
    notifyListeners();
  });

  Map<String, Object?> _row(SavedSkill skill) => {
    'id': skill.id,
    'name': skill.name,
    'description': skill.description,
    'instructions': skill.instructions,
    'script': skill.script,
    'enabled': skill.enabled ? 1 : 0,
    'revision': skill.revision,
    'icon': skill.icon,
  };
  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.catchError((Object error) {});
    return result;
  }
}
