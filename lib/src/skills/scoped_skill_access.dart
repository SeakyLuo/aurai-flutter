import '../domain/resource_scope.dart';
import 'skill_store.dart';

/// Each tool instance carries its own context; simultaneous group runs must not
/// change the shared contact's skill store context.
mixin ScopedSkillAccess {
  SkillStore get store;
  String? get groupId;
  String? Function()? get currentProjectId;

  List<SavedSkill> get scopedLibrary => store.library
      .where(
        (skill) => matchesResourceScope(
          skill.scopes,
          groupId,
          projectId: currentProjectId?.call(),
        ),
      )
      .toList();

  SavedSkill scopedRead(String name) {
    final matches = scopedLibrary
        .where((s) => s.id == name || s.name == name)
        .toList();
    if (matches.isEmpty) throw StateError('技能不存在或不在当前会话的使用范围内');
    if (matches.length > 1) throw StateError('存在同名技能，请使用技能列表中的技能 ID');
    return matches.single;
  }

  List<SavedSkill> scopedDependencies(SavedSkill skill) {
    final dependencies = store.resolvedDependencies(scopedRead(skill.id));
    for (final dependency in dependencies) {
      scopedRead(dependency.id);
    }
    return dependencies;
  }

  Future<void> checkScopeChange(SavedSkill value) async {
    if (!matchesResourceScope(
      value.scopes,
      groupId,
      projectId: currentProjectId?.call(),
    )) {
      throw StateError('使用范围需要包含当前会话的群聊或项目');
    }
    final memberGroups = await store.currentGroupMemberships();
    if (value.scopes.any(
      (scope) => switch (scope.type) {
        'group' => !memberGroups.contains(scope.id),
        'project' => scope.id != currentProjectId?.call(),
        _ => true,
      },
    )) {
      throw StateError('只能选择自己所在的群聊或当前项目');
    }
  }
}
