import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/model_provider.dart';
import '../domain/request_adapter.dart';

RequestAdapter? adapterFor(ModelConfig config) =>
    config.details?.requestAdapters[config.model] ??
    config.details?.requestAdapters[''];
ProviderProtocol requestProtocol(ModelConfig config) =>
    adapterFor(config)?.protocol ?? config.protocol;

Future<({String path, Map<String, Object?> body})> transformRequest(
  ModelConfig config,
  Map<String, Object?> body,
) async {
  final protocol = requestProtocol(config);
  final path = protocol == ProviderProtocol.responses
      ? 'responses'
      : 'chat/completions';
  final script = adapterFor(config)?.script ?? '';
  if (script.trim().isEmpty) return (path: path, body: body);
  const channel = MethodChannel('com.haiskynology.aurai/platform');
  try {
    final raw = await channel.invokeMethod<String>('transformModelRequest', {
      'script': script,
      'input': jsonEncode({'model': config.model, 'path': path, 'body': body}),
    });
    final result = jsonDecode(raw!) as Map;
    final nextPath = result['path'] as String;
    final uri = Uri.parse(nextPath);
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment ||
        nextPath.startsWith('/') ||
        uri.pathSegments.contains('..') ||
        nextPath.isEmpty) {
      throw const FormatException('接口路径必须是相对路径，例如 chat/completions');
    }
    final nextBody = Map<String, Object?>.from(result['body'] as Map);
    if (nextBody['stream'] != body['stream']) {
      throw const FormatException('转换不能改变 stream；响应协议请使用协议选项切换');
    }
    return (path: nextPath, body: nextBody);
  } on Object catch (error) {
    throw ModelProviderException('请求转换失败', detail: error.toString());
  }
}

Future<Map<String, Object?>> previewRequestAdapter(ModelConfig config) async {
  final chat =
      requestProtocol(config) == ProviderProtocol.openaiChatCompletions;
  final before = <String, Object?>{
    'model': config.model,
    'stream': true,
    if (chat)
      'messages': [
        {'role': 'user', 'content': 'Reply OK'},
      ]
    else
      'input': 'Reply OK',
    if (chat) 'max_tokens': 1024 else 'max_output_tokens': 1024,
  };
  final after = await transformRequest(config, before);
  return {'before': before, 'path': after.path, 'after': after.body};
}
