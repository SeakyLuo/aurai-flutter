import '../domain/tool_models.dart';
import '../domain/message_image.dart';
import 'dart:convert';
import 'dart:io';
import '../platform/message_image_store.dart';

class GroupMessageTool implements AgentTool, RuntimeCapabilityAgentTool {
  GroupMessageTool(this.send);
  final Future<Map<String, Object?>> Function(Map<String, Object?>) send;

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'sendGroupMessages',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    description:
        'Publish one or several complete messages to this group as yourself. '
        'Send local pictures with imagePaths, with or without text; this sends existing images, not image generation. '
        'Use member IDs from the supplied roster for mentions and message IDs from '
        'the supplied history for quotes. Never invent IDs. If new messages arrived, '
        'nothing is sent and the new messages are returned: reconsider your draft, '
        'then retry or remain silent. Do not repeat already executed device actions. '
        'Only explicit instructions from the human user may change participation. '
        'paused stops automatic replies, active resumes them, unchanged preserves state. '
        'An empty messages array allows silence or participation changes.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'groupId': {
          'type': ['string', 'null'],
          'description':
              'Null uses the current group. In private chat supply a group ID discovered with listGroupChats/readGroupChat; only participation changes with empty messages are allowed there.',
        },
        'messages': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'text': {
                'type': 'string',
                'description':
                    'May be empty when images are attached. Network reference images may also use Markdown image syntax.',
              },
              'imagePaths': {
                'type': 'array',
                'maxItems': 4,
                'items': {'type': 'string'},
                'description':
                    'Optional local JPG, PNG or WebP file paths obtained from tools or message history, never invented. Files are copied into permanent message storage. Up to 4 images, each under 10 MB.',
              },
              'mentionIds': {
                'type': 'array',
                'items': {'type': 'string'},
                'uniqueItems': true,
                'description': 'Optional; omit when not mentioning anyone.',
              },
              'quoteMessageId': {
                'type': ['string', 'null'],
              },
            },
            'required': ['text'],
            'additionalProperties': false,
          },
        },
        'participation': {
          'type': 'string',
          'enum': ['unchanged', 'paused', 'active'],
        },
      },
      'required': ['groupId', 'messages', 'participation'],
      'additionalProperties': false,
    },
  );

  @override
  Future<void> cancel() async {}

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final store = MessageImageStore();
    final imported = <MessageImage>[];
    var sent = false;
    try {
      final arguments = Map<String, Object?>.of(call.arguments);
      final messages = arguments['messages'];
      if (messages is! List) {
        throw ArgumentError('messages 必须是消息数组；不发送消息请传 []');
      }
      final normalized = <Map<String, Object?>>[];
      for (final raw in messages) {
        if (raw is! Map || raw['text'] is! String) {
          throw ArgumentError('每条消息必须包含 text 字符串');
        }
        final item = Map<String, Object?>.from(raw);
        final paths = item['imagePaths'] ?? const <String>[];
        if (paths is! List ||
            paths.length > 4 ||
            paths.any((p) => p is! String)) {
          throw ArgumentError('imagePaths 必须是最多 4 个本地图片路径');
        }
        if ((item['text'] as String).trim().isEmpty && paths.isEmpty) {
          throw ArgumentError('消息需要文字或图片');
        }
        if (!item.containsKey('mentionIds')) item['mentionIds'] = <String>[];
        final mentions = item['mentionIds'];
        if (mentions is! List || mentions.any((id) => id is! String)) {
          throw ArgumentError('mentionIds 必须是成员 ID 数组；不 @ 成员请省略或传 []');
        }
        if (item['quoteMessageId'] != null &&
            item['quoteMessageId'] is! String) {
          throw ArgumentError('quoteMessageId 必须是消息 ID 字符串');
        }
        normalized.add(item);
      }
      if (![
        'unchanged',
        'paused',
        'active',
      ].contains(arguments['participation'])) {
        throw ArgumentError('participation 必须是 unchanged、paused 或 active');
      }
      arguments['messages'] = normalized;
      await store.initialize();
      for (final item in normalized) {
        final images = <MessageImage>[];
        for (final path in item['imagePaths'] as List? ?? const []) {
          final file = File(path as String);
          if (await file.length() > 10 * 1024 * 1024) {
            throw ArgumentError('图片不能超过 10 MB');
          }
          final image = await store.importBytes(await file.readAsBytes());
          imported.add(image);
          images.add(image);
        }
        item['_images'] = images;
      }
      final output = await send(arguments);
      sent = output['sent'] == true;
      final images =
          (output.remove('_images') as List<MessageImage>?) ?? const [];
      final attachments = await Future.wait([
        for (final image in images)
          File(image.path).readAsBytes().then(
            (bytes) => ToolAttachment(
              type: ToolAttachmentType.image,
              mimeType: image.mimeType,
              base64Data: base64Encode(bytes),
            ),
          ),
      ]);
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: output,
        attachments: attachments,
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {
          'message': switch (error) {
            ArgumentError() => error.message,
            ImageInputException() => error.message,
            FileSystemException() => '无法读取图片文件，请确认文件路径和访问权限',
            _ => error.toString(),
          },
        },
      );
    } finally {
      if (!sent) await store.remove(imported);
    }
  }
}
