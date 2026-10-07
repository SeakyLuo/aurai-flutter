import 'dart:convert';

import '../domain/model_provider.dart';
import 'memory_evidence.dart';
import 'memory_search.dart';

void validateMemoryFragments(
  List<Map<String, Object?>> changes,
  List<Map<String, Object?>> candidates,
  MemoryEvidence evidence,
) {
  Never fail(String field, String reason, Object? value) =>
      throw ModelProviderException(
        '自动记忆整理失败：$field $reason',
        detail: jsonEncode({
          'field': field,
          'reason': reason,
          'value': value,
          'model_changes': changes,
        }),
      );

  if (changes.length > 12) fail('changes', '超过 12 条', changes.length);
  final available = {for (final record in evidence.records) record['source']};
  final existing = {for (final record in candidates) record['id']: record};
  final used = <String>{};
  for (final (index, change) in changes.indexed) {
    final path = 'changes[$index]';
    final text = change['text'] as String;
    if (text.trim().isEmpty) fail('$path.text', '内容为空', text);
    if (text.length > memoryTextLimit) {
      fail('$path.text', '超过 $memoryTextLimit 字', text.length);
    }
    final ids = (change['ids'] as List).cast<String>();
    final versions = (change['versions'] as List).cast<int>();
    if (ids.length > 8) fail('$path.ids', '超过 8 条', ids.length);
    if (ids.length != versions.length) {
      fail('$path.versions', '与替换记忆的数量不一致', versions);
    }
    for (final (position, id) in ids.indexed) {
      if (!existing.containsKey(id)) {
        fail('$path.ids[$position]', '不是本次提供的已有记忆', id);
      }
      if (!used.add(id)) fail('$path.ids[$position]', '重复替换同一条记忆', id);
      if (existing[id]!['manual'] == 1) {
        fail('$path.ids[$position]', '不能替换手动记忆', id);
      }
      if (versions[position] != existing[id]!['version']) {
        fail('$path.versions[$position]', '与本次提供的记忆版本不一致', versions[position]);
      }
    }
    final sources = (change['sources'] as List).cast<String>();
    if (sources.isEmpty) fail('$path.sources', '没有引用证据', sources);
    if (sources.length > 24) fail('$path.sources', '超过 24 条', sources.length);
    for (final (position, source) in sources.indexed) {
      if (!available.contains(source)) {
        fail('$path.sources[$position]', '不是本次提供的证据', source);
      }
    }
    if (!['note', 'experience'].contains(change['kind'])) {
      fail('$path.kind', '必须是 note 或 experience', change['kind']);
    }
    if (![
      'reported',
      'observed',
      'inferred',
      'dream',
    ].contains(change['assertion'])) {
      fail('$path.assertion', '不是支持的事实类型', change['assertion']);
    }
    final keywords = (change['keywords'] as List).cast<String>();
    if (keywords.length > 12)
      fail('$path.keywords', '超过 12 个', keywords.length);
    for (final (position, keyword) in keywords.indexed) {
      if (keyword.isEmpty || keyword.length > 40) {
        fail('$path.keywords[$position]', '必须为 1 到 40 字', keyword);
      }
    }
    final entities = change['entities'] as List;
    if (entities.length > 8) fail('$path.entities', '超过 8 个', entities.length);
    for (final (position, entity) in entities.indexed) {
      final name = entity['name'] as String;
      final entityPath = '$path.entities[$position]';
      if (name.isEmpty || name.length > 80) {
        fail('$entityPath.name', '必须为 1 到 80 字', name);
      }
      final aliases = (entity['aliases'] as List).cast<String>();
      if (aliases.length > 8)
        fail('$entityPath.aliases', '超过 8 个', aliases.length);
      for (final (aliasIndex, alias) in aliases.indexed) {
        if (alias.isEmpty || alias.length > 80) {
          fail('$entityPath.aliases[$aliasIndex]', '必须为 1 到 80 字', alias);
        }
      }
    }
  }
}
