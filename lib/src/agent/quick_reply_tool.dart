import '../domain/tool_models.dart';

const quickReplyTexts = {
  'dog': '🐶 狗头',
  'like': '👍 点赞',
  'dislike': '👎 点踩',
  'love': '❤️ 喜欢',
  'laugh': '😂 哈哈',
  'celebrate': '🎉 庆祝',
  'plus_one': '+1 附议',
  'done': '✅ 完成',
  'received': '👌 收到',
  'viewing': '👀 在看',
  'question': '❓ 有疑问',
  'smile': '😊 开心',
  'surprised': '😮 惊讶',
  'sad': '😢 难过',
  'angry': '😡 生气',
  'thinking': '🤔 思考',
  'sweat': '😅 尴尬',
  'speechless': '😑 无语',
  'cool': '😎 酷',
  'clap': '👏 鼓掌',
  'thanks': '🙏 感谢',
  'strong': '💪 加油',
  'fire': '🔥 火热',
  'hundred': '💯 满分',
  'hug': '🤗 抱抱',
  'heart_eyes': '😍 心动',
  'rainbow': '🌈 彩虹',
  'flower': '🌸 送花',
  'gift': '🎁 礼物',
  'rocket': '🚀 起飞',
  'coffee': '☕ 喝杯咖啡',
  'diamond': '💎 珍贵',
  'clover': '🍀 好运',
  'ice': '🧊 冷静',
  'party': '🎊 欢庆',
  'bullseye': '🎯 说到点上',
  'penguin': '🐧 企鹅',
  'cat': '🐱 猫猫',
  'unicorn': '🦄 独角兽',
  'ghost': '👻 幽灵',
  'robot': '🤖 机器人',
  'poop': '💩 便便',
  'melon': '🍉 吃瓜',
  'lemon': '🍋 酸了',
  'beer': '🍺 干杯',
  'broken_heart': '💔 心碎',
  'wilted_flower': '🥀 枯萎',
  'sleep': '💤 困了',
};

class QuickReplyTool implements AgentTool, RuntimeCapabilityAgentTool {
  QuickReplyTool(this.send);
  final Future<Map<String, Object?>> Function(String messageId, String key)
  send;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'sendQuickReply',
    capabilityId: 'local.messages',
    safety: ToolSafety.lowRisk,
    description:
        '向当前会话中可见的消息发送快捷回复，显示在原消息下方。每人一项，发送其他类型替换自己的原有类型。适合点赞、点踩、喜欢、哈哈、庆祝、附议、完成、收到、在看、疑问，避免为简单回应另发长消息。messageId 从消息上下文获取，不要让用户填写。',
    inputSchema: {
      'type': 'object',
      'properties': {
        'messageId': {'type': 'string'},
        'key': {'type': 'string', 'enum': quickReplyTexts.keys.toList()},
      },
      'required': ['messageId', 'key'],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: await send(
          call.arguments['messageId'] as String,
          call.arguments['key'] as String,
        ),
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'message': error.toString()},
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
