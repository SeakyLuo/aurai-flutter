import 'dart:convert';
import 'line_change_count.dart';

class WorkspaceFileChange {
  WorkspaceFileChange(
    this.path,
    this.before,
    this.after, {
    this.beforeLines,
    this.afterLines,
    this.displayPath,
  });
  final String path;
  final String? displayPath;
  final String? before;
  final String? after;
  final List<String>? beforeLines;
  final List<String>? afterLines;
  late final LineChangeCount? lineCount =
      beforeLines == null || afterLines == null
      ? null
      : countLineChanges(beforeLines!, afterLines!);

  String get label => before == null
      ? '新增'
      : after == null
      ? '删除'
      : '修改';
}

class WorkspaceFileChanges {
  const WorkspaceFileChanges(this.files, {required this.complete});
  final List<WorkspaceFileChange> files;
  final bool complete;
  LineChangeCount? get lineCount {
    final counts = files.map((file) => file.lineCount).nonNulls.toList();
    if (counts.isEmpty) return null;
    return (
      added: counts.fold(0, (sum, count) => sum + count.added),
      removed: counts.fold(0, (sum, count) => sum + count.removed),
    );
  }

  bool get allLinesCounted => files.every((file) => file.lineCount != null);

  factory WorkspaceFileChanges.fromResults(Iterable<String?> results) {
    final changes = <String, WorkspaceFileChange>{};
    var complete = true;
    for (final json in results) {
      if (json == null) continue;
      final output = jsonDecode(json) as Map<String, dynamic>;
      if (output['fileChangesComplete'] == false) complete = false;
      final rows = output['fileChanges'] as List?;
      if (rows == null) continue;
      for (final row in rows.cast<Map>()) {
        final path = row['path'] as String;
        final previous = changes[path];
        changes[path] = WorkspaceFileChange(
          path,
          previous == null ? row['before'] as String? : previous.before,
          row['after'] as String?,
          displayPath: row['displayPath'] as String?,
          beforeLines: previous == null
              ? (row['beforeLines'] as List?)?.cast<String>()
              : previous.beforeLines,
          afterLines: (row['afterLines'] as List?)?.cast<String>(),
        );
      }
    }
    return WorkspaceFileChanges(
      changes.values.where((file) => file.before != file.after).toList()
        ..sort((a, b) => a.path.compareTo(b.path)),
      complete: complete,
    );
  }
}
