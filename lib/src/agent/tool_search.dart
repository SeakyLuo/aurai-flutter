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
        'Find and load tools for your next model turn. Start with offset 0; use nextOffset only to inspect more matches. Search by a specific task in Chinese or English, or exact tool name. Available domains: web, image generation/editing (generateImage), reusable skills, Aurai AI contacts/address book, group chat creation/members/management, memory, conversation history/database, scheduled tasks, notifications, model balance/top-up, Android UI/apps/settings, network diagnostics, Android API/scripts and shell. Returns at most 5 relevant matches and loads them; up to 20 search candidates are kept separately from tools used during the current run, which remain loaded. Recent tools are restored from this conversation on later user messages. Explicit tool names in a query restrict results to those tools. Call tools already provided directly; search only when a needed tool is absent. Searching does not execute the tool or grant permission.',
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
    final catalog = registry.catalog;
    final words = RegExp(
      r'[a-z0-9_]+',
    ).allMatches(query).map((match) => match[0]!).toSet();
    final namedTools = catalog
        .where((tool) => words.contains(tool.name.toLowerCase()))
        .map((tool) => tool.name)
        .toSet();
    final ranked = [
      for (final definition in catalog)
        if (definition.name != 'searchTools' && definition.name != 'askUser')
          if (namedTools.isEmpty || namedTools.contains(definition.name))
            (definition: definition, score: _score(definition, query)),
    ]..removeWhere((entry) => entry.score == 0);
    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0
          ? score
          : a.definition.name.compareTo(b.definition.name);
    });
    if (ranked.isNotEmpty && namedTools.isEmpty) {
      final bestScore = ranked.first.score;
      ranked.removeWhere((entry) => entry.score < bestScore * 0.4);
    }
    final matches = ranked
        .skip(offset)
        .take(5)
        .map((entry) => entry.definition)
        .toList();
    registry.load(matches.reversed.map((tool) => tool.name));
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
      'local.app' =>
        '会话 私聊 创建聊天 发消息 发送 消息 conversation direct private chat create send message',
      'local.diagnostics' =>
        '日志 报错 错误 执行失败 排查 诊断 log logs error failure diagnostics',
      'local.messages' =>
        '快捷回复 点赞 附议 收到 在看 疑问 quick reply reaction 消息 私聊 群聊 小程序 HTML 交互 卡片 图表 可视化 message private group html interactive card visualization',
      'local.group_chats' =>
        '群聊 群组 发群消息 发送群消息 私聊发群 跨群发送 创建建群 拉群 成员 添加 移除 退群 改名 重命名 group chat send message private cross-group members roster create rename',
      'model.settings' =>
        '请求转换 参数映射 兼容性 JavaScript request adapter transform 模型设置 默认模型 图片理解 图片生成 视频理解 视频生成 配置 切换 model settings default vision image video generation provider',
      'local.ai_contacts' =>
        '好友 加好友 添加好友 私聊 通讯录 联系人 AI 角色 创建 修改 删除 归档 恢复 查询 friends friend private chat ai contact address book persona',
      'android.scheduled_tasks' => '定时 计划 提醒 scheduled schedule task reminder',
      'local.attachments' =>
        '附件 文档 文件 PDF Word 音频 视频 attachment file document audio video',
      'local.history' =>
        '群历史 群聊记录 读取群消息 历史 会话 消息 数据库 记录 group chat history conversation message database',
      'android.accessibility' || 'android.observe' || 'screenAccess' =>
        '屏幕 界面 点击 输入 滚动 返回 主页 screen ui click input scroll back home',
      'images.generate' =>
        '生图 画图 绘图 绘画 生成图片 图片生成 文生图 图生图 图片编辑 改图 参考图 立绘 插画 海报 表情包 image generation generate draw edit image reference illustration',
      'web.images' => '图片 配图 参考图 找图 搜图 照片 image images photo gallery visual',
      'web.read' => '网页 搜索 浏览 新闻 联网 web search browse news',
      'skills' => '技能 工具 自定义 复用 skill reusable custom',
      'memory.manage' =>
        '记忆 记住 整理 补充 查询 新增 修改 删除 时间 memory remember organize list read create update delete timestamp',
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
