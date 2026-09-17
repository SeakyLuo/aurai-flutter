import 'skill_icon_names.dart';
import 'skill_sort.dart';
import '../domain/message_sender.dart';
import 'skill_permission.dart';
import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'skill_library_store.dart';

class SavedSkill {
  const SavedSkill({
    this.id = '',
    this.ownerId = '',
    this.visibility = 'private',
    this.visibleTo = const [],
    this.dependencyIds = const [],
    required this.name,
    required this.description,
    required this.instructions,
    required this.script,
    required this.enabled,
    required this.revision,
    this.icon = 'skill',
  });
  final String ownerId, visibility;
  final List<String> visibleTo;
  final String id, name, description, instructions, script;
  final List<String> dependencyIds;
  final String icon;
  final bool enabled;
  final int revision;
  Map<String, Object?> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'visibility': visibility,
    'visibleTo': visibleTo,
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
    ownerId: data['ownerId'] as String? ?? data['owner_id'] as String? ?? '',
    visibility: data['visibility'] as String? ?? 'private',
    visibleTo: List<String>.from(data['visibleTo'] as List? ?? const []),
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
  SkillStore({this.ownerId = 'agent:aurai'});
  final String ownerId;
  bool get usesInstallations => ownerId != MessageSender.localUser.id;
  static final _stores = <SkillStore>{};
  static Future<void> _pending = Future.value();
  late Database _database;
  final _skills = <String, SavedSkill>{};
  final _installations = <String, Map<String, Object?>>{};
  final _statistics = <String, Map<String, int>>{};
  final _timestamps = <String, Map<String, int>>{};
  final _members = <MessageSender>[];
  SkillSort sort = SkillSort.createdDescending;
  SkillPermission defaultPermission = SkillPermission.lowRisk;
  List<MessageSender> get members => List.unmodifiable(_members);
  String _key(String key) => ownerId == 'agent:aurai' ? key : '$ownerId:$key';
  List<SavedSkill> get library => List.unmodifiable(_skills.values);
  List<SavedSkill> get skills =>
      library.where((s) => isInstalled(s.id)).toList();
  bool isInstalled(String id) => _installations.containsKey(id);
  bool canManageVisibility(SavedSkill skill) =>
      ownerId == MessageSender.localUser.id || skill.ownerId == ownerId;
  bool canEdit(SavedSkill skill) =>
      canManageVisibility(skill) || skill.visibility == 'public';
  String ownerName(SavedSkill skill) =>
      _members.where((m) => m.id == skill.ownerId).firstOrNull?.name ??
      '已移除的联系人';
  DateTime? createdAt(String id) => _time(id, 'created');
  DateTime? updatedAt(String id) => _time(id, 'updated');
  int useCount(String id) => _statistics[id]?['uses'] ?? 0;
  DateTime? _time(String id, String field) {
    final value = _timestamps[id]?[field];
    return value == null ? null : DateTime.fromMicrosecondsSinceEpoch(value);
  }

  SkillPermission? permissionOverrideFor(String id) {
    final value = _installations[id]?['permission'] as String?;
    return value == null ? null : SkillPermission.values.byName(value);
  }

  SkillPermission permissionFor(String id) {
    final permission = permissionOverrideFor(id) ?? defaultPermission;
    if (permission == SkillPermission.all &&
        _installations[id]?['approved_revision'] != _skills[id]?.revision) {
      return SkillPermission.lowRisk;
    }
    return permission;
  }

  int compareSkills(SavedSkill a, SavedSkill b) {
    final values = sort.field == 'uses' ? _statistics : _timestamps;
    final first = values[a.id]?[sort.field] ?? 0;
    final second = values[b.id]?[sort.field] ?? 0;
    final comparison = first.compareTo(second);
    return comparison != 0
        ? (sort.descending ? -comparison : comparison)
        : a.name.compareTo(b.name);
  }

  Future<void> saveSort(SkillSort value) => _enqueue(() async {
    await _state('skill_sort', value.name);
    sort = value;
    notifyListeners();
  });
  Future<void> saveDefaultPermission(SkillPermission value) =>
      _enqueue(() async {
        await _state('skill_default_permission', value.name);
        defaultPermission = value;
        notifyListeners();
      });
  Future<void> _state(String key, String value) => _database.insert(
    'app_state',
    {'key': _key(key), 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  Future<void> recordUse(String id) => _enqueue(() async {
    _statistics[id] = {...?_statistics[id], 'uses': useCount(id) + 1};
    await _state('skill_statistics', jsonEncode(_statistics));
    notifyListeners();
  });
  Future<void> initialize(Database database) async {
    _database = database;
    final migrated = await database.query(
      'app_state',
      where: 'key = ?',
      whereArgs: ['skills_migrated'],
    );
    if (migrated.isEmpty) {
      final preferences = SharedPreferencesAsync();
      final raw = await preferences.getString('saved_skills');
      final legacy = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
      await database.transaction((txn) async {
        final batch = txn.batch();
        for (final item in legacy) {
          final skill = SavedSkill.fromJson(
            (item as Map).cast<String, Object?>(),
          );
          final id = _newId();
          batch.insert('skills', {
            ..._row(skill),
            'id': id,
            'owner_id': 'agent:aurai',
          });
          batch.insert('skill_installations', {
            'skill_id': id,
            'owner_id': 'agent:aurai',
            'enabled': skill.enabled ? 1 : 0,
            'approved_revision': skill.revision,
          });
        }
        batch.insert('app_state', {'key': 'skills_migrated', 'value': '1'});
        await batch.commit(noResult: true);
      });
      await preferences.remove('saved_skills');
    }
    await _reload();
    _stores.add(this);
  }

  Future<List<List<Map<String, Object?>>>> _snapshot() => Future.wait([
    _database.query('skills'),
    _database.query('skill_dependencies'),
    _database.query('skill_installations'),
    _database.query('skill_visibility_members'),
    _database.query('message_senders', where: 'archived = 0'),
    _database.query(
      'app_state',
      where: 'key LIKE ? OR key LIKE ? OR key LIKE ?',
      whereArgs: [
        '%skill_sort',
        '%skill_statistics',
        '%skill_default_permission',
      ],
    ),
  ]);
  Future<void> reload() => _enqueue(() async {
    await _reload();
    notifyListeners();
  });

  Future<void> _reload() async => _applySnapshot(await _snapshot());
  void _applySnapshot(List<List<Map<String, Object?>>> rows) {
    _installations
      ..clear()
      ..addEntries(
        rows[2]
            .where((r) => r['owner_id'] == ownerId)
            .map((r) => MapEntry(r['skill_id'] as String, r)),
      );
    final dependencies = <String, List<String>>{},
        grants = <String, List<String>>{};
    for (final row in rows[1]) {
      dependencies
          .putIfAbsent(row['skill_id'] as String, () => [])
          .add(row['dependency_id'] as String);
    }
    for (final row in rows[3]) {
      grants
          .putIfAbsent(row['skill_id'] as String, () => [])
          .add(row['member_id'] as String);
    }
    _skills.clear();
    for (final row in rows[0]) {
      final id = row['id'] as String;
      if (ownerId != MessageSender.localUser.id &&
          row['owner_id'] != ownerId &&
          row['visibility'] != 'public' &&
          !(row['visibility'] == 'selected' &&
              (grants[id] ?? []).contains(ownerId)))
        continue;
      _skills[id] = SavedSkill.fromJson({
        ...row,
        'enabled': _installations[id]?['enabled'] == 1,
        'dependencyIds': dependencies[id] ?? [],
        'visibleTo': grants[id] ?? [],
      });
    }
    _members
      ..clear()
      ..addAll(rows[4].map(MessageSender.fromRow));
    _statistics.clear();
    _timestamps.clear();
    for (final row in rows[5]) {
      if (row['key'] == _key('skill_sort'))
        sort = SkillSort.values.byName(row['value'] as String);
      if (row['key'] == _key('skill_default_permission'))
        defaultPermission = SkillPermission.values.byName(
          row['value'] as String,
        );
      if ((row['key'] as String).endsWith('skill_statistics')) {
        final statistics =
            (jsonDecode(row['value'] as String) as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, Map<String, int>.from(v as Map)),
            );
        if (row['key'] == _key('skill_statistics')) {
          _statistics.addAll(statistics);
        }
        for (final entry in statistics.entries) {
          final times = _timestamps.putIfAbsent(entry.key, () => {});
          if (entry.value['created'] case final created?) {
            times['created'] = min(times['created'] ?? created, created);
          }
          if (entry.value['updated'] case final updated?) {
            times['updated'] = max(times['updated'] ?? updated, updated);
          }
        }
      }
    }
  }

  Future<void> _publish() async {
    final snapshot = await _snapshot();
    for (final store
        in _stores.where((s) => identical(s._database, _database)).toList()) {
      store._applySnapshot(snapshot);
      store.notifyListeners();
    }
  }

  @override
  void dispose() {
    _stores.remove(this);
    super.dispose();
  }

  SavedSkill read(String name) {
    final matches = library
        .where((s) => s.name == name || s.id == name)
        .toList();
    if (matches.isEmpty) throw StateError('技能不存在或不可见，请重新查看技能库');
    if (matches.length > 1) throw StateError('存在同名技能，请使用技能列表中的技能 ID');
    return matches.single;
  }

  SavedSkill readId(String id) {
    final skill = _skills[id];
    if (skill == null) throw StateError('技能不存在或不可见，请重新选择');
    return skill;
  }

  List<SavedSkill> resolvedDependencies(SavedSkill root) {
    final found = <String, SavedSkill>{};
    void visit(SavedSkill skill) {
      if (!isInstalled(skill.id)) throw StateError('请先安装技能“${skill.name}”');
      if (!skill.enabled) throw StateError('技能“${skill.name}”已停用');
      if (found.containsKey(skill.id)) return;
      found[skill.id] = skill;
      for (final id in skill.dependencyIds) {
        visit(readId(id));
      }
    }

    visit(readId(root.id));
    return found.values.toList();
  }

  String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.catchError((Object error) {});
    return result;
  }

  Map<String, Object?> _row(SavedSkill s) => {
    'id': s.id,
    'name': s.name,
    'description': s.description,
    'instructions': s.instructions,
    'script': s.script,
    'enabled': 1,
    'revision': s.revision,
    'icon': s.icon,
    'visibility': s.visibility,
  };
}
