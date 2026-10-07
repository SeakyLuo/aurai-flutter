import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

const memoryTextLimit = 2000;

String memoryFingerprint(String text) =>
    sha256.convert(utf8.encode(text)).toString();

Set<String> memoryTerms(String text) {
  final terms = <String>{};
  for (final match in RegExp(
    r'[a-z0-9_]+|[\u3400-\u9fff]+',
    caseSensitive: false,
  ).allMatches(text.toLowerCase())) {
    final word = match.group(0)!;
    if (RegExp(r'^[a-z0-9_]').hasMatch(word)) {
      terms.add(word);
    } else if (word.length == 1) {
      terms.add(word);
    } else {
      for (var i = 0; i < word.length - 1; i++) {
        terms.add(word.substring(i, i + 2));
      }
    }
  }
  return terms;
}

Map<String, Object?> memorySearchColumns(
  String text, {
  List<String> keywords = const [],
  List<Map<String, Object?>> entities = const [],
}) {
  final names = [
    ...keywords,
    for (final entity in entities) ...[
      entity['name'] as String,
      ...(entity['aliases'] as List).cast<String>(),
    ],
  ];
  return {
    'keywords_json': jsonEncode(keywords),
    'entities_json': jsonEncode(entities),
    'terms_json': jsonEncode({
      for (final term in memoryTerms(text)) term: 1,
      for (final term in memoryTerms(names.join(' '))) term: 3,
      for (final name in names) name.toLowerCase(): 5,
    }),
    'fingerprint': memoryFingerprint(text),
  };
}

class MemorySearch {
  MemorySearch(this.database, this.ownerId, {this.scope = ''});
  final DatabaseExecutor database;
  final String ownerId, scope;
  String get visibility => 'owner_id = ?';
  List<Object?> get arguments => [ownerId];

  Future<bool> preferProjectFor(String query) async {
    if (!scope.startsWith('project:')) return false;
    if (RegExp(
      r'跨项目|所有项目|各个项目|多个项目|cross.project|across projects',
      caseSensitive: false,
    ).hasMatch(query))
      return false;
    if (query.isEmpty) return true;
    final otherProjects = await database.query(
      'development_projects',
      columns: ['id'],
      where: 'id != ? AND instr(lower(?), lower(name)) > 0',
      whereArgs: [scope.substring(8), query],
      limit: 1,
    );
    return otherProjects.isEmpty;
  }

  Future<List<Map<String, Object?>>> find(
    String query, {
    int limit = 21,
    int offset = 0,
    bool preferCurrentProject = true,
  }) async {
    if (query.length > 12000 || limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError('Invalid memory search window');
    }
    final terms = memoryTerms(query).take(64).toSet();
    final prefer = preferCurrentProject && await preferProjectFor(query);
    if (query.trim().isNotEmpty) terms.add(query.trim().toLowerCase());
    if (terms.isEmpty) {
      // A bounded recency bonus reduces interference without hiding other projects.
      return database.rawQuery(
        '''SELECT * FROM user_memories
        WHERE owner_id = ? AND state = 'active'
        ORDER BY MAX(updated_at, last_used_at) ${prefer ? "+ CASE WHEN memory_scope = ? THEN 259200000 WHEN memory_scope NOT LIKE 'project:%' THEN 86400000 ELSE 0 END" : ''} DESC, id
        LIMIT ? OFFSET ?''',
        [ownerId, if (prefer) scope, limit, offset],
      );
    }
    return database.rawQuery(
      '''SELECT m.*, SUM(t.weight) AS relevance
      FROM memory_terms t INNER JOIN user_memories m ON m.id = t.memory_id
      WHERE t.owner_id = ? AND t.term IN (SELECT value FROM json_each(?))
      AND m.state = 'active'
      GROUP BY m.id ORDER BY SUM(t.weight) ${prefer ? "* CASE WHEN m.memory_scope = ? THEN 1.25 WHEN m.memory_scope NOT LIKE 'project:%' THEN 1.1 ELSE 1.0 END" : ''} DESC, MAX(m.updated_at, m.last_used_at) DESC, m.id
      LIMIT ? OFFSET ?''',
      [ownerId, jsonEncode(terms.toList()), if (prefer) scope, limit, offset],
    );
  }
}
