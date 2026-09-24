import 'request_adapter_runner.dart';
import 'dart:convert';
import 'dart:io';
import '../domain/model_provider.dart';

Future<Map<String, Object?>> checkProviderConnection(
  ModelConfig config,
  String model,
) async {
  if (model.trim().isEmpty) throw ArgumentError('请先选择模型');
  config = config.copyWith(model: model);
  final chat =
      requestProtocol(config) == ProviderProtocol.openaiChatCompletions;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    return await (() async {
      final base = config.baseUrl.replaceFirst(RegExp(r'/$'), '');
      final transformed = await transformRequest(config, {
        'model': model,
        if (chat)
          'messages': [
            {'role': 'user', 'content': 'Reply OK'},
          ]
        else
          'input': 'Reply OK',
        'stream': false,
        if (chat) 'max_tokens': 16 else 'max_output_tokens': 16,
      });
      final request = await client.postUrl(
        Uri.parse('$base/${transformed.path}'),
      );
      request.followRedirects = false;
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${config.apiKey}')
        ..contentType = ContentType.json;
      request.write(jsonEncode(transformed.body));
      final response = await request.close();
      if (response.statusCode != 200) {
        return {
          'connected': false,
          'httpStatus': response.statusCode,
          'message': '测试请求未成功。请检查模型权限、额度和请求参数；这不一定是网络故障。',
        };
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 65536) throw StateError('测试响应超过大小限制');
      }
      final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final valid = chat
          ? body['choices'] is List && (body['choices'] as List).isNotEmpty
          : body['output'] is List && (body['output'] as List).isNotEmpty;
      return {
        'connected': valid,
        'httpStatus': 200,
        'model': model,
        'message': valid ? '聊天接口已返回有效响应；未测试工具调用或图片能力' : '接口没有返回有效的聊天响应',
      };
    })().timeout(const Duration(seconds: 45));
  } finally {
    client.close(force: true);
  }
}
