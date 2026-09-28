import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../storage/project_directory.dart';
import 'aurai_platform.dart';

/// Capture each checkout separately, including worktrees sharing a Git database.
class ProjectRunSnapshots {
  ProjectRunSnapshots(this.platform, this.database, this.runId);
  final AuraiPlatform platform;
  final Database database;
  final String runId;
  final List<ProjectDirectory> _pending = [];
  String _task(ProjectDirectory directory) =>
      '${directory.workspaceId}__$runId';
  Future<Map<String, Object?>> _invoke(
    ProjectDirectory directory,
    String operation,
  ) => platform.deviceExtension('projectDevelopmentOperation', {
    'projectId': directory.workspaceId,
    'operation': operation,
    'arguments': {'taskId': _task(directory)},
  });

  Future<void> begin(List<ProjectDirectory> directories) async {
    var completed = false;
    try {
      for (final directory in directories.where((item) => item.managed)) {
        final result = await _invoke(directory, 'beginProjectGitTask');
        if (result['available'] == true) _pending.add(directory);
      }
      completed = true;
    } finally {
      if (!completed) await abort();
    }
  }

  Future<ProjectGitTaskChanges?> finish() async {
    final changes = <ProjectGitTaskChanges>[];
    for (final directory in _pending.toList()) {
      final result = await _invoke(directory, 'finishProjectGitTask');
      if (result['available'] != true) continue;
      _pending.remove(directory);
      final files = result['changes'] as List;
      if (files.isEmpty) continue;
      final previewFiles = files
          .take(3)
          .cast<Map>()
          .map((file) => file.cast<String, Object?>())
          .map(ProjectGitTaskFileChange.fromJson)
          .toList();
      changes.add(
        ProjectGitTaskChanges(
          workspaceId: directory.workspaceId,
          taskId: _task(directory),
          directoryName: directory.name,
          fileCount: files.length,
          addedLines: result['addedLines'] as int,
          removedLines: result['removedLines'] as int,
          previewFiles: previewFiles,
        ),
      );
    }
    if (changes.isEmpty) return null;
    final summary = ProjectGitTaskChanges(
      workspaceId: changes.first.workspaceId,
      taskId: runId,
      fileCount: changes.fold(0, (sum, item) => sum + item.fileCount),
      addedLines: changes.fold(0, (sum, item) => sum + item.addedLines),
      removedLines: changes.fold(0, (sum, item) => sum + item.removedLines),
      directories: changes,
      previewFiles: changes
          .expand((item) => item.previewFiles)
          .take(3)
          .toList(),
    );
    await database.insert('app_state', {
      'key': 'git_task:$runId',
      'value': jsonEncode(summary.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return summary;
  }

  Future<void> abort() async {
    for (final directory in _pending.toList()) {
      await _invoke(directory, 'abortProjectGitTask');
      _pending.remove(directory);
    }
  }
}
