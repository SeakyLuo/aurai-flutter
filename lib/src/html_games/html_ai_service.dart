import '../providers/structured_result_tool.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../domain/model_provider.dart';
import '../platform/aurai_platform.dart';
import '../providers/model_context_limits.dart';
import '../providers/responses_transport.dart';

/// A page-scoped, tool-free client. Credentials and app conversations stay native.
/// JSON results use a result-only function, without access to application tools.
class HtmlAiService {
  final _jobs = <int, _AiJob>{};

  Future<Map<String, Object?>> invoke(
    int id,
    String encoded, {
    required void Function(String) onText,
  }) async {
    try {
      if (utf8.encode(encoded).length > 256 * 1024) {
        throw ArgumentError('模型请求不能超过 256 KB');
      }
      final args = (jsonDecode(encoded) as Map).cast<String, Object?>();
      if (args['operation'] == 'status') {
        final config =
            (await AuraiPlatform.instance.loadModelSettings()).activeConfig;
        final available =
            config.apiKey.isNotEmpty &&
            config.model.isNotEmpty &&
            config.baseUrl.isNotEmpty;
        return {
          'version': 1,
          'available': available,
          if (available) 'model': config.model,
          if (!available) 'reason': '请先在 Aurai 设置默认文本模型',
        };
      }
      if (args['operation'] != 'complete') throw ArgumentError('不支持的 模型操作');
      if (_jobs.containsKey(id)) throw ArgumentError('请求正在处理中');
      if (_jobs.length >= 4) throw StateError('同时最多处理 4 个 模型请求，请稍后再试');
      final messages = args['messages'];
      if (messages is! List || messages.isEmpty || messages.length > 100) {
        throw ArgumentError('请提供 1–100 条文本消息');
      }
      for (final message in messages) {
        if (message is! Map ||
            !const ['system', 'user', 'assistant'].contains(message['role']) ||
            message['content'] is! String ||
            (message['content'] as String).trim().isEmpty) {
          throw ArgumentError('消息必须包含有效的 role 和非空文本 content');
        }
      }
      final format = args['responseFormat'] ?? 'text';
      if (format != 'text' && format != 'json')
        throw ArgumentError('responseFormat 必须为 text 或 json');
      final maxTokens = args['maxOutputTokens'] ?? 4096;
      if (maxTokens is! int || maxTokens < 1 || maxTokens > 32768) {
        throw ArgumentError('maxOutputTokens 必须为 1–32768 的整数');
      }
      final job = _AiJob();
      _jobs[id] = job;
      try {
        return await _complete(
          job,
          messages,
          format as String,
          maxTokens,
          args['streamUpdates'] == true ? onText : (_) {},
        ).timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            unawaited(job.cancel());
            throw TimeoutException('模型请求超时，请重试');
          },
        );
      } finally {
        await job.cancel();
        _jobs.remove(id);
      }
    } on TimeoutException {
      return {'error': '模型请求超时，请重试', 'code': 'timeout'};
    } on ArgumentError catch (error) {
      return {'error': '${error.message}', 'code': 'invalid_request'};
    } on StateError catch (error) {
      return {'error': error.message, 'code': 'unavailable'};
    } on ModelProviderException catch (error) {
      // Do not expose provider response bodies, endpoints or credentials to pages.
      return {
        'error': switch (error.statusCode) {
          401 || 403 => '默认模型认证失败，请检查 Aurai 的模型设置',
          402 => '默认模型服务余额不足',
          429 => '默认模型服务繁忙或额度不足，请稍后重试',
          _ => '模型回复未完成，请检查模型配置或稍后重试',
        },
        'code': 'model_error',
      };
    } on Object {
      return {'error': '模型调用失败，请检查 Aurai 的默认模型设置', 'code': 'request_failed'};
    }
  }

  Future<Map<String, Object?>> _complete(
    _AiJob job,
    List messages,
    String format,
    int maxTokens,
    void Function(String) onText,
  ) async {
    final config =
        (await AuraiPlatform.instance.loadModelSettings()).activeConfig;
    job.checkCancelled();
    if (config.apiKey.isEmpty ||
        config.model.isEmpty ||
        config.baseUrl.isEmpty) {
      throw StateError('请先在 Aurai 设置默认文本模型');
    }
    final transport = ResponsesTransport(config);
    job.transport = transport;
    const resultTool = StructuredResultTool(
      'submitPageResult',
      '返回页面请求的 JSON 值，不执行页面或设备操作。',
      {
        'type': 'object',
        'properties': {'value': <String, Object?>{}},
        'required': ['value'],
        'additionalProperties': false,
      },
    );
    final response = await transport.send(
      {
        'model': config.model,
        'stream': true,
        'store': false,
        'max_output_tokens': math.min(
          maxTokens,
          ModelContextLimits.forConfig(config).outputTokens,
        ),
        if (format == 'json') ...{
          ...resultTool.request,
          'instructions':
              'Call submitPageResult with the requested JSON value in its value argument. Do not return the result in reply text.',
        },
        'input': [
          for (final message in messages)
            {'role': message['role'], 'content': message['content']},
        ],
      },
      onTextChanged: (text) {
        job.checkCancelled();
        if (utf8.encode(text).length > 512 * 1024) {
          throw const ModelProviderException('模型回复超过大小限制');
        }
        if (format == 'text') onText(text);
      },
    );
    job.checkCancelled();
    if (response['status'] != 'completed') {
      throw const ModelProviderException('模型回复未完成');
    }
    if (format == 'json') {
      final result = resultTool.read(response);
      if (result.length != 1 || !result.containsKey('value')) {
        throw FormatException('页面结果工具必须提供 value', jsonEncode(result));
      }
      final text = jsonEncode(result['value']);
      if (utf8.encode(text).length > 512 * 1024) {
        throw const ModelProviderException('模型回复超过大小限制');
      }
      onText(text);
      return {'text': text, 'json': result['value'], 'model': config.model};
    }
    final text = [
      for (final item in (response['output'] as List).cast<Map>())
        if (item['type'] == 'message')
          for (final part in (item['content'] as List).cast<Map>())
            if (part['type'] == 'output_text') part['text'] as String,
    ].join('\n');
    if (text.trim().isEmpty || utf8.encode(text).length > 512 * 1024) {
      throw const ModelProviderException('模型没有返回有效文本');
    }
    return {'text': text, 'model': config.model};
  }

  Future<void> cancel(int id) async => _jobs[id]?.cancel();

  Future<void> cancelAll() async {
    await Future.wait(_jobs.values.toList().map((job) => job.cancel()));
  }
}

class _AiJob {
  ResponsesTransport? transport;
  bool cancelled = false;
  void checkCancelled() {
    if (cancelled) throw StateError('模型请求已取消');
  }

  Future<void> cancel() async {
    cancelled = true;
    await transport?.cancel();
  }
}
