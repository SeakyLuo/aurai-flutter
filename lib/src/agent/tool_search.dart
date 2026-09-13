import '../domain/agent_models.dart';
import '../domain/tool_models.dart';
import 'tool_registry.dart';

class ToolSearch implements AgentTool, RuntimeCapabilityAgentTool {
  ToolSearch(this.registry);
  final ToolRegistry registry;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'searchTools',
    description:
        'Find and load tools for your next model turn. Start with offset 0; use nextOffset only to inspect more matches. Search by a specific task in Chinese or English, or exact tool name. Available domains: web, reusable skills, memory, conversation history/database, scheduled tasks, notifications, model balance/top-up, Android UI/apps/settings, network diagnostics, Android API/scripts and shell. Returns at most 10 matches and loads them; only 20 recently loaded tools are kept. Search again when a needed tool is no longer present. Searching does not execute the tool or grant permission.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'minLength': 1},
        'offset': {'type': 'integer', 'minimum': 0},
      },
      'required': ['query', 'offset'],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'runtime.tool_search',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final query = (call.arguments['query'] as String).toLowerCase().trim();
    final offset = (call.arguments['offset'] as int?) ?? 0;
    if (query.isEmpty || offset < 0) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'error': 'Enter a search query and a nonnegative offset.'},
      );
    }
    final ranked = [
      for (final definition in registry.catalog)
        if (definition.name != 'searchTools' && definition.name != 'askUser')
          (definition: definition, score: _score(definition, query)),
    ]..removeWhere((entry) => entry.score == 0);
    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0
          ? score
          : a.definition.name.compareTo(b.definition.name);
    });
    final matches = ranked
        .skip(offset)
        .take(10)
        .map((entry) => entry.definition)
        .toList();
    registry.load(matches.map((tool) => tool.name));
    return ToolResult(
      callId: call.id,
      toolName: call.name,
      status: ToolResultStatus.success,
      output: {
        'tools': [
          for (final tool in matches)
            {'name': tool.name, 'description': tool.description},
        ],
        'hasMore': offset + matches.length < ranked.length,
        if (offset + matches.length < ranked.length)
          'nextOffset': offset + matches.length,
        'message': matches.isEmpty
            ? 'No matching available tools. Try another specific keyword or domain.'
            : 'Matched tools are loaded for the next turn. Use their provided schemas; loading grants no permission.',
      },
    );
  }

  int _score(ToolDefinition tool, String query) {
    final name = tool.name.toLowerCase();
    final title = toolTitle(tool.name).toLowerCase();
    final aliases = switch (tool.capabilityId) {
      'android.scheduled_tasks' => '定时 计划 提醒 scheduled schedule task reminder',
      'local.history' =>
        '历史 会话 消息 数据库 记录 history conversation message database',
      'android.accessibility' || 'android.observe' || 'screenAccess' =>
        '屏幕 界面 点击 输入 滚动 返回 主页 screen ui click input scroll back home',
      'web.images' => '图片 配图 参考图 找图 搜图 照片 image images photo gallery visual',
      'web.read' => '网页 搜索 浏览 新闻 联网 web search browse news',
      'skills' => '技能 工具 自定义 复用 skill reusable custom',
      'memory.manage' => '记忆 记住 整理 补充 memory remember organize',
      'android.network' => '网络 连接 域名 诊断 network dns tls http',
      'android.runtime' => '设备 系统 接口 脚本 Android API script runtime',
      'android.notifications.observe' ||
      'android.notifications.send' => '通知 推送 提醒 notification push alert',
      'android.apps' => '应用 软件 启动 app launch',
      _ => '',
    };
    final text =
        '$name $title ${tool.description.toLowerCase()} ${tool.capabilityId} $aliases';
    if (name == query) return 10000;
    var score = title.contains(query) || name.contains(query) ? 100 : 0;
    final words = RegExp(
      r'[a-z0-9_]+|[㐀-鿿]+',
    ).allMatches(query).map((m) => m[0]!);
    for (final word in words) {
      if (text.contains(word)) score += 10;
      if (RegExp(r'[㐀-鿿]').hasMatch(word)) {
        for (var i = 0; i + 1 < word.length; i++) {
          final pair = word.substring(i, i + 2);
          if (title.contains(pair))
            score += 5;
          else if (text.contains(pair))
            score++;
        }
      }
    }
    return score;
  }

  @override
  Future<void> cancel() async {}
}
