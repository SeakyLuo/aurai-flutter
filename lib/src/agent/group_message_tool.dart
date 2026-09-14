import '../domain/error_message.dart';
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
    name: 'sendGroupMessage',
    capabilityId: 'local.group_chats',
    safety: ToolSafety.lowRisk,
    description:
        'Publish exactly one complete message to this group as yourself per call. Call again only if you have another message to send. '
        'Send local pictures with imagePaths, with or without text; this sends existing images, not image generation. '
        'Use member IDs from the supplied roster for mentions and message IDs from '
        'the supplied history for quotes. Never invent IDs. If new messages arrived, '
        'nothing is sent and the new messages are returned: reconsider your draft, '
        'then retry or remain silent. Do not repeat already executed device actions. '
        'Only explicit instructions from the human user may change participation. '
        'paused stops automatic replies, active resumes them, unchanged preserves state. '
        'A null message allows silence or participation changes. '
        'message must be a nested JSON object, never JSON encoded inside a string. '
        'Use JSON null, not the string "null". Minimal current-group send: '
        '{"groupId":null,"message":{"text":"你好"},"participation":"unchanged"}. '
        'On a parameter error, fix the indicated field and retry only this send; do not repeat other actions.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'groupId': {
          'type': ['string', 'null'],
          'description':
              'JSON null (without quotes) uses the current group; the string "null" is invalid. In private chat supply a group ID discovered with listGroupChats/readGroupChat; only participation changes with message set to null are allowed there.',
        },
        'message': {
          'type': ['object', 'null'],
          'description':
              'A nested object such as {"text":"你好"}, or JSON null for silence. Do not stringify or double-encode the object; text belongs inside message.',
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
        'participation': {
          'type': 'string',
          'enum': ['unchanged', 'paused', 'active'],
        },
      },
      'required': ['groupId', 'message', 'participation'],
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
      final groupId = arguments['groupId'];
      if (!arguments.containsKey('groupId')) {
        throw ArgumentError('缺少 groupId；发给当前群请传 "groupId":null，不要省略');
      }
      if (groupId == 'null' || (groupId != null && groupId is! String)) {
        throw ArgumentError(
          'groupId 必须是实际群 ID 或 JSON null；不要传字符串 "null"。当前群请用 "groupId":null',
        );
      }
      if (!arguments.containsKey('message')) {
        throw ArgumentError('请提供单条 message；不发送消息请传 null，不支持消息数组');
      }
      final raw = arguments['message'];
      Map<String, Object?>? message;
      if (raw != null) {
        if (raw is! Map) {
          throw ArgumentError(
            'message 类型错误：收到 ${raw.runtimeType}，需要 JSON 对象或 null，不能是序列化后的字符串或数组。请直接传 "message":{"text":"你好"}，不要对 message 再做 JSON 编码',
          );
        }
        if (!raw.containsKey('text')) {
          throw ArgumentError(
            'message 对象缺少 text 字段。示例："message":{"text":"你好"}；仅发送图片时 text 传空字符串',
          );
        }
        if (raw['text'] is! String) {
          throw ArgumentError(
            'message.text 必须是字符串，不能是 null、数字或对象；仅发送图片时传 "text":""',
          );
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
        message = item;
      }
      if (![
        'unchanged',
        'paused',
        'active',
      ].contains(arguments['participation'])) {
        throw ArgumentError('participation 必须是 unchanged、paused 或 active');
      }
      arguments['message'] = message;
      await store.initialize();
      if (message != null) {
        final item = message;
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
            FileSystemException() =>
              '无法读取图片文件，请确认文件路径和访问权限：${errorMessage(error)}',
            _ => error.toString(),
          },
        },
      );
    } finally {
      if (!sent) await store.remove(imported);
    }
  }
}
