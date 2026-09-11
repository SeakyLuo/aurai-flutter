import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../agent/system_prompt.dart';
import '../domain/model_provider.dart';
import '../domain/tool_models.dart';

class DeepSeekResponsesProvider implements ModelProvider {
  DeepSeekResponsesProvider(this.config);

  final ModelConfig config;
  final List<Map<String, Object?>> _history = <Map<String, Object?>>[];
  HttpClient? _activeClient;
  bool _cancelRequested = false;

  @override
  bool get supportsImageInput => config.supportsImageInput;

  @override
  Future<ModelTurn> respond(ModelRequest request) async {
    _cancelRequested = false;
    _appendRequestInput(request);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    _activeClient = client;
    try {
      final uri = Uri.parse('${_baseUrl(config.baseUrl)}/responses');
      final httpRequest = await client.postUrl(uri);
      httpRequest.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${config.apiKey}')
        ..contentType = ContentType.json;
      httpRequest.write(jsonEncode(_requestBody(request)));
      final response = await httpRequest.close().timeout(
        const Duration(seconds: 60),
      );
      final body = await utf8.decoder.bind(response).join();
      if (_cancelRequested) {
        throw const ModelProviderException('任务已停止');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ModelProviderException(
          _friendlyStatus(response.statusCode),
          detail: body,
        );
      }
      final json = (jsonDecode(body) as Map<Object?, Object?>)
          .cast<String, Object?>();
      _appendResponseOutput(json);
      return _parseResponse(json);
    } on TimeoutException {
      throw const ModelProviderException('模型响应超时，请重试');
    } on SocketException catch (error) {
      if (_cancelRequested) {
        throw const ModelProviderException('任务已停止');
      }
      throw ModelProviderException('无法连接模型服务，请检查网络', detail: '$error');
    } on HandshakeException catch (error) {
      throw ModelProviderException('模型服务的安全连接失败', detail: '$error');
    } finally {
      client.close(force: true);
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
    }
  }

  void _appendRequestInput(ModelRequest request) {
    if (_history.isEmpty) {
      _history.addAll(
        request.messages.map(
          (message) => <String, Object?>{
            'role': message.role.name,
            'content': message.text,
          },
        ),
      );
      return;
    }
    _history.addAll(request.toolResults.map(_functionCallOutput));
  }

  Map<String, Object?> _functionCallOutput(
    ToolResult result,
  ) => <String, Object?>{
    'type': 'function_call_output',
    'call_id': result.callId,
    'output': result.attachments.isEmpty
        ? jsonEncode(result.toModelJson())
        : <Map<String, Object?>>[
            <String, Object?>{
              'type': 'input_text',
              'text': jsonEncode(result.toModelJson()),
            },
            for (final attachment in result.attachments)
              <String, Object?>{
                'type': 'input_image',
                'image_url':
                    'data:${attachment.mimeType};base64,${attachment.base64Data}',
                'detail': attachment.detail,
              },
          ],
  };

  Map<String, Object?> _requestBody(ModelRequest request) => <String, Object?>{
    'model': config.model,
    'instructions': '$agentSystemPrompt\n${_capabilitySummary(request)}',
    'input': _history,
    'tools': request.tools
        .map(
          (tool) => <String, Object?>{
            'type': 'function',
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.inputSchema,
          },
        )
        .toList(growable: false),
    'tool_choice': 'auto',
  };

  void _appendResponseOutput(Map<String, Object?> json) {
    final output = (json['output']! as List<Object?>)
        .cast<Map<Object?, Object?>>();
    for (final rawItem in output) {
      final item = rawItem.cast<String, Object?>();
      switch (item['type']) {
        case 'reasoning':
          _history.add(<String, Object?>{
            'type': 'reasoning',
            'content': item['content']!,
          });
        case 'function_call':
          _history.add(<String, Object?>{
            'type': 'function_call',
            'call_id': item['call_id']!,
            'name': item['name']!,
            'arguments': item['arguments']!,
          });
        case 'message':
          _history.add(<String, Object?>{
            'role': 'assistant',
            'content': item['content']!,
          });
      }
    }
  }

  String _capabilitySummary(ModelRequest request) {
    final lines = request.capabilities.map(
      (capability) =>
          '- ${capability.id}: ${capability.availability.name} (${capability.reason})',
    );
    return 'Current device capabilities:\n${lines.join('\n')}';
  }

  ModelTurn _parseResponse(Map<String, Object?> json) {
    final output = (json['output']! as List<Object?>)
        .cast<Map<Object?, Object?>>();
    final calls = <ToolCall>[];
    final textParts = <String>[];
    for (final rawItem in output) {
      final item = rawItem.cast<String, Object?>();
      if (item['type'] == 'function_call') {
        calls.add(
          ToolCall(
            id: item['call_id']! as String,
            name: item['name']! as String,
            arguments:
                (jsonDecode(item['arguments']! as String)
                        as Map<Object?, Object?>)
                    .cast<String, Object?>(),
          ),
        );
      }
      if (item['type'] == 'message') {
        final content = (item['content']! as List<Object?>)
            .cast<Map<Object?, Object?>>();
        for (final rawContent in content) {
          final contentItem = rawContent.cast<String, Object?>();
          if (contentItem['type'] == 'output_text') {
            textParts.add(contentItem['text']! as String);
          }
        }
      }
    }
    return ModelTurn(
      continuationToken: json['id']! as String,
      toolCalls: calls,
      text: textParts.isEmpty ? null : textParts.join('\n'),
    );
  }

  @override
  Future<void> cancel() async {
    _cancelRequested = true;
    _activeClient?.close(force: true);
  }

  String _friendlyStatus(int statusCode) => switch (statusCode) {
    401 || 403 => 'DeepSeek 认证失败，请检查 API 密钥',
    402 => 'DeepSeek 余额不足，请先充值',
    429 => 'DeepSeek 请求过于频繁，请稍后重试',
    >= 500 => 'DeepSeek 服务暂时不可用，请稍后重试',
    _ => 'DeepSeek 请求失败',
  };

  String _baseUrl(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
