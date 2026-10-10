import 'dart:convert';

/// References are separate from gameplay snapshots and read one section at a time.
abstract final class MiniappResources {
  static Map<String, Object?> read(
    String html,
    String key, {
    required bool isHost,
    Map<String, Object?>? state,
    int offset = 0,
  }) {
    final pattern = RegExp(
      '<script type="application/aurai-resource" id="${RegExp.escape(key)}">'
      r'([\s\S]*?)</script>',
    );
    final match = pattern.firstMatch(html);
    if (match == null) throw ArgumentError('小程序资料不存在：$key');
    final resource = (jsonDecode(match.group(1)!) as Map)
        .cast<String, Object?>();
    final access = resource['access'] as String;
    if (access == 'page' || (access == 'host' && !isHost)) {
      throw StateError('无权读取此小程序资料');
    }
    if (resource['stateField'] case final String field) {
      if (state == null) return {'stateField': field};
      final exclude = resource['exclude'] as Map?;
      final rows = (state[field] as List)
          .where(
            (row) =>
                exclude == null ||
                (row as Map)[exclude['field']] != exclude['value'],
          )
          .toList();
      final page = rows.reversed.skip(offset).take(20).toList();
      return {
        'key': key,
        'title': resource['title'],
        'items': page,
        'total': rows.length,
        if (offset + page.length < rows.length)
          'nextOffset': offset + page.length,
      };
    }
    return {
      'key': key,
      'title': resource['title'],
      if (resource.containsKey('sections')) 'sections': resource['sections'],
      if (resource.containsKey('content')) 'content': resource['content'],
    };
  }
}
