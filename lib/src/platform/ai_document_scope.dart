import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../storage/development_projects.dart';

/// Android grants belong to the app; these grants limit which AI can use them.
class AiDocumentScope {
  AiDocumentScope(this.database, this.senderId, {this.project});
  final Database database;
  final String senderId;
  DevelopmentProject? project;
  final Set<String> _folders = {};
  String get _key => 'ai_documents:$senderId';
  Future<void> initialize() async {
    final rows = await database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_key],
      limit: 1,
    );
    if (rows.isNotEmpty)
      _folders.addAll(
        (jsonDecode(rows.single['value'] as String) as List).cast<String>(),
      );
  }

  bool allows(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    final parts = uri.pathSegments;
    if (project != null) return _within(value, project!.rootUri);
    return _folders.any((folder) {
      final root = Uri.parse(folder);
      final rootParts = root.pathSegments;
      return uri.scheme == root.scheme &&
          uri.authority == root.authority &&
          parts.length >= 2 &&
          rootParts.length >= 2 &&
          parts[0] == 'tree' &&
          parts[1] == rootParts[1];
    });
  }

  bool _within(String value, String rootValue) {
    final uri = Uri.parse(value);
    final root = Uri.parse(rootValue);
    if (uri.scheme == 'aurai') {
      return uri.scheme == root.scheme &&
          uri.authority == root.authority &&
          uri.pathSegments.first == root.pathSegments.first;
    }
    final parts = uri.pathSegments;
    final rootParts = root.pathSegments;
    return uri.scheme == root.scheme &&
        uri.authority == root.authority &&
        parts.length >= 2 &&
        rootParts.length >= 2 &&
        parts[0] == 'tree' &&
        parts[1] == rootParts[1];
  }

  Future<void> grant(String value) async {
    final next = {..._folders, value};
    await database.insert('app_state', {
      'key': _key,
      'value': jsonEncode(next.toList()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _folders.add(value);
  }

  Map<String, Object?> filter(Map<String, Object?> output) => {
    ...output,
    'folders': [
      if (project != null)
        {
          'uri': project!.rootUri,
          'name': project!.name,
          'source': '项目',
          'path': '',
          'readable': true,
          'writable': true,
        },
      if (project == null)
        ...(output['folders'] as List).where(
          (folder) => allows((folder as Map)['uri'] as String),
        ),
    ],
  };
}
