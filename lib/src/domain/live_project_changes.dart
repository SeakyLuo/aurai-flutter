class LiveProjectChanges {
  const LiveProjectChanges({
    required this.workspaceId,
    required this.taskId,
    required this.name,
    required this.data,
  });
  final String workspaceId, taskId, name;
  final Map<String, Object?> data;
  int get fileCount => (data['changes'] as List).length;
  int get added => data['addedLines'] as int;
  int get removed => data['removedLines'] as int;
}
