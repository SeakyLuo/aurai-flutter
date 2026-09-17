part of 'skill_store.dart';

extension SkillLibraryOperations on SkillStore {
  Future<void> setPermission(String id, SkillPermission? permission) =>
      _enqueue(() async {
        final skill = readId(id);
        if (!isInstalled(id)) throw StateError('请先安装此技能');
        await _commit((txn) async {
          await txn.update(
            'skill_installations',
            {
              'permission': permission?.name,
              'approved_revision': skill.revision,
            },
            where: 'skill_id = ? AND owner_id = ?',
            whereArgs: [id, ownerId],
          );
        });
      });
  Future<void> install(String id) => _enqueue(() async {
    final skill = readId(id);
    await _commit((txn) async {
      await txn.insert('skill_installations', {
        'skill_id': id,
        'owner_id': ownerId,
        'enabled': 1,
        'approved_revision': skill.revision,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  });
  Future<void> uninstall(String id) => _enqueue(() async {
    await _commit((txn) async {
      await txn.delete(
        'skill_installations',
        where: 'skill_id = ? AND owner_id = ?',
        whereArgs: [id, ownerId],
      );
    });
  });
  Future<void> setEnabled(String id, bool enabled) => _enqueue(() async {
    readId(id);
    if (!isInstalled(id)) throw StateError('请先安装此技能');
    await _commit((txn) async {
      await txn.update(
        'skill_installations',
        {'enabled': enabled ? 1 : 0},
        where: 'skill_id = ? AND owner_id = ?',
        whereArgs: [id, ownerId],
      );
    });
  });
  Future<void> save(
    SavedSkill value, {
    String? previousName,
    SkillPermission? permission,
    bool updatePermission = false,
    int? approvedRevision,
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
    final old = previousName == null
        ? null
        : read(value.id.isEmpty ? previousName : value.id);
    if (old != null &&
        !canEdit(old) &&
        !(requiresEditApproval(old) && approvedRevision == old.revision))
      throw StateError('修改此技能需要用户审批');
    if (old != null && old.revision != value.revision)
      throw StateError('技能已被修改，请返回后重新打开');
    if (!['private', 'public', 'selected'].contains(value.visibility))
      throw StateError('请选择有效的可见范围');
    if (old != null &&
        !canManageVisibility(old) &&
        (value.visibility != old.visibility ||
            !setEquals(value.visibleTo.toSet(), old.visibleTo.toSet()))) {
      throw StateError('仅创建者可以修改可见范围');
    }
    if (value.visibility == 'selected' && value.visibleTo.isEmpty)
      throw StateError('请选择可见的人或 AI');
    if (value.visibleTo.any((id) => !_members.any((m) => m.id == id)))
      throw StateError('可见范围包含已移除的联系人，请重新选择');
    final creator = old?.ownerId ?? ownerId;
    if (library.any(
      (s) => s.ownerId == creator && s.name == name && s.id != old?.id,
    ))
      throw StateError('创建者已有同名技能，请换一个名称');
    final saved = SavedSkill(
      id: old?.id ?? _newId(),
      ownerId: creator,
      visibility: value.visibility,
      visibleTo: value.visibility == 'selected'
          ? value.visibleTo.toSet().toList()
          : [],
      name: name,
      description: value.description.trim(),
      instructions: value.instructions.trim(),
      script: value.script,
      enabled: value.enabled,
      revision: (old?.revision ?? 0) + 1,
      icon: value.icon,
      dependencyIds: value.dependencyIds.toSet().toList(),
    );
    for (final id in saved.dependencyIds) {
      readId(id);
    }
    final allEdges = await _database.query('skill_dependencies');
    final graph = <String, List<String>>{};
    for (final edge in allEdges) {
      graph
          .putIfAbsent(edge['skill_id'] as String, () => [])
          .add(edge['dependency_id'] as String);
    }
    graph[saved.id] = saved.dependencyIds;
    final visiting = <String>{}, visited = <String>{};
    void visit(String id) {
      if (visiting.contains(id)) throw StateError('技能依赖不能形成循环');
      if (!visited.add(id)) return;
      visiting.add(id);
      for (final dependency in graph[id] ?? <String>[]) {
        visit(dependency);
      }
      visiting.remove(id);
    }

    visit(saved.id);
    final now = DateTime.now().microsecondsSinceEpoch;
    final stats = {
      ..._statistics,
      saved.id: {
        ...?_statistics[saved.id],
        if (old == null) 'created': now,
        'updated': now,
      },
    };
    await _commit((txn) async {
      if (old == null) {
        await txn.insert('skills', {..._row(saved), 'owner_id': creator});
        if (usesInstallations)
          await txn.insert('skill_installations', {
            'skill_id': saved.id,
            'owner_id': ownerId,
            'enabled': value.enabled ? 1 : 0,
            'approved_revision': saved.revision,
          });
      } else {
        final changed = await txn.update(
          'skills',
          _row(saved),
          where: 'id = ? AND revision = ?',
          whereArgs: [saved.id, old.revision],
        );
        if (changed != 1) throw StateError('技能已被修改，请返回后重新打开');
      }
      if (updatePermission) {
        await txn.update(
          'skill_installations',
          {'permission': permission?.name, 'approved_revision': saved.revision},
          where: 'skill_id = ? AND owner_id = ?',
          whereArgs: [saved.id, ownerId],
        );
      }
      await txn.insert('app_state', {
        'key': _key('skill_statistics'),
        'value': jsonEncode(stats),
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
      batch.delete(
        'skill_visibility_members',
        where: 'skill_id = ?',
        whereArgs: [saved.id],
      );
      for (final id in saved.visibleTo) {
        batch.insert('skill_visibility_members', {
          'skill_id': saved.id,
          'member_id': id,
        });
      }
      await batch.commit(noResult: true);
      // Removing visibility also removes the installation and its permission grant.
      if (saved.visibility != 'public') {
        await txn.delete(
          'skill_installations',
          where:
              'skill_id = ? AND owner_id != ? AND owner_id != ? AND owner_id NOT IN (SELECT member_id FROM skill_visibility_members WHERE skill_id = ?)',
          whereArgs: [saved.id, creator, MessageSender.localUser.id, saved.id],
        );
      }
    });
  });
  Future<void> delete(
    String name, {
    int? approvedRevision,
    int? expectedRevision,
  }) => _enqueue(() async {
    final skill = read(name);
    if (expectedRevision != null && expectedRevision != skill.revision)
      throw StateError('技能已被修改，请重新确认删除');
    if (!canEdit(skill) &&
        !(requiresEditApproval(skill) && approvedRevision == skill.revision))
      throw StateError('删除此技能需要用户审批');
    final references = await _database.query(
      'skill_dependencies',
      columns: ['skill_id'],
      where: 'dependency_id = ?',
      whereArgs: [skill.id],
      limit: 1,
    );
    if (references.isNotEmpty) throw StateError('其他技能仍依赖此技能，请先移除依赖');
    await _commit((txn) async {
      await txn.delete('skills', where: 'id = ?', whereArgs: [skill.id]);
    });
  });
}
