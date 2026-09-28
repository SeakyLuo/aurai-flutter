class ProjectDirectory {
  const ProjectDirectory({
    required this.uri,
    required this.name,
    this.repositoryUri,
  });
  final String uri;
  final String name;
  final String? repositoryUri;
  bool get managed => Uri.parse(uri).scheme == 'aurai';
  bool get worktree => repositoryUri != null;
  String get workspaceId => Uri.parse(uri).pathSegments.first;
  Map<String, Object?> toJson() => {
    'uri': uri,
    'name': name,
    'repository_uri': repositoryUri,
  };
  factory ProjectDirectory.fromJson(Map value) => ProjectDirectory(
    uri: value['uri'] as String,
    name: value['name'] as String,
    repositoryUri: value['repository_uri'] as String?,
  );
  bool contains(String value) {
    final child = Uri.parse(value);
    final root = Uri.parse(uri);
    if (child.scheme != root.scheme || child.authority != root.authority)
      return false;
    if (managed)
      return child.pathSegments.isNotEmpty &&
          child.pathSegments.first == root.pathSegments.first;
    return child.pathSegments.length >= 2 &&
        root.pathSegments.length >= 2 &&
        child.pathSegments[0] == 'tree' &&
        child.pathSegments[1] == root.pathSegments[1];
  }
}
