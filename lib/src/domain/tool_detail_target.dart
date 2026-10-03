enum ToolDetailType {
  skill,
  project,
  group,
  aiContact,
  scheduledTask,
  miniapp,
  miniappPublication,
  model,
  provider,
}

/// Tool-result navigation metadata. IDs locate objects; names and icons are
/// display snapshots so rendering a result never needs database lookups.
class ToolDetailTarget {
  const ToolDetailTarget({
    required this.type,
    required this.id,
    required this.name,
    this.icon,
  });
  final ToolDetailType type;
  final String id;
  final String name;
  final String? icon;
  factory ToolDetailTarget.fromJson(Map<String, dynamic> json) =>
      ToolDetailTarget(
        type: ToolDetailType.values.byName(json['type'] as String),
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String?,
      );
  Map<String, Object?> toJson() => {
    'type': type.name,
    'id': id,
    'name': name,
    if (icon != null) 'icon': icon,
  };
}
