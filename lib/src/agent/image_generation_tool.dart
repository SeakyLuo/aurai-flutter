import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/error_message.dart';
import '../domain/image_generation_config.dart';
import '../domain/tool_models.dart';
import '../providers/image_generation_client.dart';
import '../platform/svg_image.dart';

class ImageGenerationTool implements AgentTool, RuntimeCapabilityAgentTool {
  ImageGenerationTool(this.run, {required this.configuration});
  final ImageGenerationConfig? Function() configuration;
  final Future<Map<String, Object?>> Function(
    Map<String, Object?> arguments,
    ImageGenerationClient client,
  )
  run;
  ImageGenerationClient? _client;

  String get _modelDescription {
    final selected = configuration();
    if (selected == null) {
      return 'No default image model is configured. Ask the user to configure image generation in model settings first. ';
    }
    final model = selected.model;
    return 'Current default image model: ${model.name}. '
        '${model.supportsReference ? 'Reference image editing is supported.' : 'Text-to-image only; referenceImage must be null.'} '
        'Supports up to ${model.maxImages} images per call. Image charges scale with count. '
        'Supported aspect ratios: ${['auto', ...model.aspectRatios].join(', ')}. ';
  }

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'generateImage',
    description:
        _modelDescription +
        'Generate one image, or edit an existing image, using the user-configured image model. '
            'Saves the generated image locally and publishes it in the current conversation. Do not call another message tool to send it again. '
            'Returns the sent message ID, imagePaths and mimeTypes. Use only when an image is requested or helps the task. '
            'referenceImage accepts a known local image path, HTTP(S) image URL, or image data URL; images may come from any conversation. '
            'Use readAttachment to obtain a stored image path when necessary. Never invent paths. '
            'Use null for text-to-image. If configuration is missing, opens image settings without charging; '
            'wait for the user to configure it. Do not automatically retry failures: the provider may have charged.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'prompt': {'type': 'string', 'minLength': 1, 'maxLength': 16000},
        'aspectRatio': {
          'type': 'string',
          'enum': ['auto', '1:1', '16:9', '9:16', '4:3', '3:4'],
          'description':
              'Use auto unless the user needs a specific aspect ratio.',
        },
        'referenceImage': {
          'type': ['string', 'null'],
        },
        'count': {
          'type': 'integer',
          'minimum': 1,
          'maximum': configuration()?.model.maxImages ?? 10,
          'default': 1,
          'description': 'Number of images to generate. Omit for one image.',
        },
      },
      'required': ['prompt', 'aspectRatio', 'referenceImage'],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'images.generate',
    executionTimeout: Duration(minutes: 7),
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final client = ImageGenerationClient();
    _client = client;
    try {
      final prompt = call.arguments['prompt'];
      if (prompt is! String || prompt.trim().isEmpty || prompt.length > 16000) {
        throw ArgumentError('请输入 1–16000 字的图片描述');
      }
      if (![
        'auto',
        '1:1',
        '16:9',
        '9:16',
        '4:3',
        '3:4',
      ].contains(call.arguments['aspectRatio'])) {
        throw ArgumentError('请选择自动、方形、横向或竖向画幅');
      }
      final count = call.arguments['count'] as int? ?? 1;
      final maxImages = configuration()?.model.maxImages;
      if (count < 1) throw ArgumentError('每次至少生成 1 张图片');
      if (maxImages != null && count > maxImages) {
        throw ArgumentError('当前生图模型每次最多生成 $maxImages 张图片');
      }
      final output = await run(call.arguments, client);
      final attachments = <ToolAttachment>[];
      if (output['generated'] == true) {
        final paths = (output['imagePaths'] as List).cast<String>();
        final mimeTypes = (output['mimeTypes'] as List).cast<String>();
        for (var index = 0; index < paths.length; index++) {
          final vision = await readVisionImage(
            File(paths[index]),
            mimeTypes[index],
          );
          attachments.add(
            ToolAttachment(
              type: ToolAttachmentType.image,
              mimeType: vision.mimeType,
              base64Data: base64Encode(vision.bytes),
              detail: 'auto',
            ),
          );
        }
      }
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
        status: client.cancelled
            ? ToolResultStatus.cancelled
            : ToolResultStatus.error,
        output: {
          'generated': false,
          'error': client.cancelled
              ? '已停止等待生成；服务商可能仍在处理，请勿自动重试'
              : switch (error) {
                  SocketException() ||
                  HandshakeException() => '生图服务连接失败，请检查网络和服务地址',
                  TimeoutException() => '等待生图超时，服务商可能仍在处理，请勿自动重试',
                  FormatException() || TypeError() => '生图服务返回了无法识别的结果，请检查接口配置',
                  _ => errorMessage(error),
                },
          'retryAutomatically': false,
        },
      );
    } finally {
      client.close();
      _client = null;
    }
  }

  @override
  Future<void> cancel() async => _client?.cancel();
}
