import 'package:sqflite/sqflite.dart';
import 'development_projects.dart';
import 'project_directory.dart';

class ProjectDirectories {
  const ProjectDirectories(this.database);
  final Database database;
  Future<Set<String>> projectsUsingRepository(
    String uri,
  ) async => (await database.query(
    'project_directories',
    columns: ['project_id'],
    distinct: true,
    where:
        'directory_uri = ? OR directory_uri IN (SELECT uri FROM workspace_directories WHERE repository_uri = ?)',
    whereArgs: [uri, uri],
  )).map((row) => row['project_id'] as String).toSet();
  Future<List<ProjectDirectory>> list(
    DevelopmentProject project,
  ) async => (await database.query(
    'workspace_directories',
    where:
        'uri IN (SELECT directory_uri FROM project_directories WHERE project_id = ?)',
    whereArgs: [project.id],
    orderBy: 'name, uri',
  )).map(ProjectDirectory.fromJson).toList();

  Future<List<ProjectDirectory>> available(
    DevelopmentProject project,
  ) async => (await database.query(
    'workspace_directories',
    where:
        'uri NOT IN (SELECT directory_uri FROM project_directories WHERE project_id = ?)',
    whereArgs: [project.id],
    orderBy: 'name, uri',
  )).map(ProjectDirectory.fromJson).toList();

  Future<void> add(
    DevelopmentProject project,
    ProjectDirectory directory,
  ) async {
    await database.transaction((txn) async {
      final existing = await txn.query(
        'project_directories',
        columns: ['directory_uri'],
        where: 'project_id = ? AND directory_uri = ?',
        whereArgs: [project.id, directory.uri],
      );
      if (existing.isNotEmpty) throw StateError('此目录已加入项目');
      await txn.insert(
        'workspace_directories',
        directory.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.insert('project_directories', {
        'project_id': project.id,
        'directory_uri': directory.uri,
      });
    });
  }

  Future<void> detach(DevelopmentProject project, String uri) async {
    await database.delete(
      'project_directories',
      where: 'project_id = ? AND directory_uri = ?',
      whereArgs: [project.id, uri],
    );
  }

  Future<void> addAll(
    DevelopmentProject project,
    List<ProjectDirectory> directories,
  ) => database.transaction((txn) async {
    final batch = txn.batch();
    for (final directory in directories) {
      batch.insert(
        'workspace_directories',
        directory.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      batch.insert('project_directories', {
        'project_id': project.id,
        'directory_uri': directory.uri,
      });
    }
    await batch.commit(noResult: true);
  });

  Future<void> removeWorktree(String uri) async {
    await database.delete(
      'workspace_directories',
      where: 'uri = ?',
      whereArgs: [uri],
    );
  }
}
