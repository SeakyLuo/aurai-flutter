class MemoryChange {
  const MemoryChange({
    required this.ids,
    required this.before,
    required this.text,
    required this.reason,
  });
  final List<String> ids;
  final List<String> before;
  final String text;
  final String reason;
  String get label => ids.isEmpty
      ? '补充'
      : text.isEmpty
      ? '删除'
      : ids.length > 1
      ? '合并'
      : '更新';
  String get description =>
      '$label\n${before.join('\n')}\n${text.isEmpty ? '建议移除' : '→ $text'}\n原因：$reason';
}

class MemoryPlan {
  const MemoryPlan(this.revision, this.changes);
  final int revision;
  final List<MemoryChange> changes;
  String get description => changes.map((e) => e.description).join('\n\n');
}
