import '../domain/source_date.dart';
import '../domain/tool_models.dart';

class WebSourceRegistry {
  final sources = <String, Map<String, Object?>>{};

  Map<String, Object?> record(Map entry) {
    final url = entry['url'] as String;
    final metadata = <String, Object?>{
      ...?sources[url],
      'url': url,
      'title': entry['title'],
      if (entry['siteName'] != null) 'siteName': entry['siteName'],
      if (entry['publishedAt'] != null) ...{
        'publishedAt': entry['publishedAt'],
        'dateOrigin': 'page',
      },
    };
    return sources[url] = metadata;
  }
}

class SourceDatesTool implements AgentTool, RuntimeCapabilityAgentTool {
  SourceDatesTool(this.registry);
  final WebSourceRegistry registry;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'setSourceDates',
    description:
        'Supplement publication dates for sources already returned by searchWeb or readWebPage in this task, only when page metadata lacks a date. Use explicit publication dates found in source text, search snippets or user-provided evidence. Do not guess or use retrieval/current/update dates as publication dates. Provide a short evidence quote. Use ISO dates YYYY-MM-DD, or timestamps with HH:mm or HH:mm:ss only if that precision is known. Page-provided dates always take priority. The app formats the date automatically; continue citing ordinary Markdown links.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'sources': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 10,
          'items': {
            'type': 'object',
            'properties': {
              'url': {'type': 'string'},
              'publishedAt': {'type': 'string'},
              'evidence': {'type': 'string', 'minLength': 1, 'maxLength': 500},
            },
            'required': ['url', 'publishedAt', 'evidence'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['sources'],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'web.read',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final updates = (call.arguments['sources'] as List).cast<Map>();
    final pending = <String, Map<String, Object?>>{};
    for (final update in updates) {
      final url = update['url'] as String;
      final current = registry.sources[url];
      final date = update['publishedAt'] as String;
      if (current == null || SourceDate.tryParse(date) == null) {
        return ToolResult(
          callId: call.id,
          toolName: definition.name,
          status: ToolResultStatus.error,
          output: {
            'error': current == null ? '只能补充本次已搜索或读取的来源' : '请提供有效的 ISO 日期或时间',
          },
        );
      }
      pending[url] = current['dateOrigin'] == 'page'
          ? current
          : {
              ...current,
              'publishedAt': date,
              'dateOrigin': 'model',
              'dateEvidence': update['evidence'],
            };
    }
    registry.sources.addAll(pending);
    return ToolResult(
      callId: call.id,
      toolName: definition.name,
      status: ToolResultStatus.success,
      output: {'results': pending.values.toList()},
    );
  }

  @override
  Future<void> cancel() async {}
}
