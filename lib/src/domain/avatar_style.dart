class AvatarStyle {
  const AvatarStyle({this.icon = 'person', this.color = 'slate', this.path});
  final String icon;
  final String color;
  final String? path;

  Map<String, Object?> get columns => {
    'avatar_icon': icon,
    'avatar_color': color,
    'avatar_path': path,
  };

  factory AvatarStyle.fromRow(Map<String, Object?> row) => AvatarStyle(
    icon: row['avatar_icon'] == 'orbit'
        ? 'person'
        : row['avatar_icon'] as String,
    color: row['avatar_color'] as String,
    path: row['avatar_path'] as String?,
  );
}
