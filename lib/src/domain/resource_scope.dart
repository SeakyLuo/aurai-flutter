import 'package:sqflite/sqflite.dart';

/// Scope targets are independent of resource types so projects can share the
/// same bindings without introducing a second tool or skill system.
class ResourceScope {
  const ResourceScope(this.type, this.id);
  const ResourceScope.group(String id) : this('group', id);
  const ResourceScope.project(String id) : this('project', id);
  final String type, id;
  @override
  bool operator ==(Object other) =>
      other is ResourceScope && other.type == type && other.id == id;
  @override
  int get hashCode => Object.hash(type, id);
}

bool matchesResourceScope(
  Iterable<ResourceScope> scopes,
  String? groupId, {
  String? projectId,
}) =>
    scopes.isEmpty ||
    (groupId != null && scopes.contains(ResourceScope.group(groupId))) ||
    (projectId != null && scopes.contains(ResourceScope.project(projectId)));

bool matchesResourceFilter(
  Iterable<ResourceScope> scopes,
  ResourceScope? filter,
  List<Map<String, Object?>> groups,
) {
  if (filter == null) return true;
  if (scopes.contains(filter)) return true;
  if (filter.type != 'group') return false;
  final projectId =
      groups.where((g) => g['id'] == filter.id).firstOrNull?['project_id']
          as String?;
  return projectId != null && scopes.contains(ResourceScope.project(projectId));
}

Future<void> writeResourceScopes(
  DatabaseExecutor db,
  String resourceType,
  String resourceId,
  Iterable<ResourceScope> scopes,
) async {
  final batch = db.batch();
  batch.delete(
    'resource_scopes',
    where: 'resource_type = ? AND resource_id = ?',
    whereArgs: [resourceType, resourceId],
  );
  for (final scope in scopes.toSet()) {
    batch.insert('resource_scopes', {
      'resource_type': resourceType,
      'resource_id': resourceId,
      'target_type': scope.type,
      'target_id': scope.id,
    });
  }
  await batch.commit(noResult: true);
}

Map<String, List<ResourceScope>> resourceScopeMap(
  List<Map<String, Object?>> rows,
) {
  final result = <String, List<ResourceScope>>{};
  for (final row in rows) {
    result
        .putIfAbsent(row['resource_id'] as String, () => [])
        .add(
          ResourceScope(
            row['target_type'] as String,
            row['target_id'] as String,
          ),
        );
  }
  return result;
}
