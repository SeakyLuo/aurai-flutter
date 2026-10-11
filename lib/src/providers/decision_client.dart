import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/model_provider.dart';
import '../platform/aurai_platform.dart';
import 'model_purpose_catalog.dart';

class DecisionCancelled implements Exception {
  const DecisionCancelled();
}

/// Decision protocol v1: shared state + named typed questions -> typed answers.
/// Model selection and credentials stay native; callers supply no endpoint.
class DecisionQuestion {
  const DecisionQuestion.choice(this.instructions, Map<String, Object?> options)
    : type = 'choice',
      criteria = options;
  const DecisionQuestion.score(this.instructions, List<Object?> levels)
    : type = 'score',
      criteria = levels;
  const DecisionQuestion.noul(this.instructions)
    : type = 'noul',
      criteria = null;
  final String type;
  final Object instructions;
  final Object? criteria;

  Map<String, Object?> toJson() => {
    'type': type,
    'instructions': instructions,
    if (criteria != null) 'criteria': criteria,
  };
}

class DecisionClient {
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  bool _cancelled = false;
  bool get cancelled => _cancelled;

  static Future<ModelConfig?> configuration() async {
    final settings = await AuraiPlatform.instance.loadModelSettings();
    final selection = settings.modelDefaults[ModelPurpose.decision];
    if (selection == null) return null;
    final config = settings
        .profile(selection.service)
        .copyWith(model: selection.model);
    if (!config.isConfigured) return null;
    if (!modelPurposesFor(
      config,
      selection.model,
    ).contains(ModelPurpose.decision)) {
      throw StateError('默认决策模型的用途已改变，请重新选择');
    }
    return config;
  }

  static Uri endpoint(ModelConfig config) {
    if (config.service == ModelService.dmxapi) {
      return Uri.parse(config.baseUrl).replace(path: '/typesafe/v1/systemone');
    }
    if (config.protocol != ProviderProtocol.typeSafe) {
      throw StateError('当前供应商未配置 TypeSafe System One 决策协议');
    }
    final base = config.baseUrl.replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base/systemone');
  }

  Future<Map<String, Map<String, Object?>>> evaluate({
    required ModelConfig config,
    required Object state,
    required Map<String, DecisionQuestion> questions,
  }) async {
    if (_cancelled) throw const DecisionCancelled();
    if (questions.isEmpty) throw ArgumentError('请提供决策问题');
    for (final q in questions.values) {
      if (q.type == 'choice' &&
          ((q.criteria as Map).isEmpty || (q.criteria as Map).length > 255)) {
        throw ArgumentError('单个选择问题需要 1–255 个选项');
      }
      if (q.type == 'score' &&
          ((q.criteria as List).length < 2 ||
              (q.criteria as List).length > 10)) {
        throw ArgumentError('评分问题需要 2–10 个档位');
      }
    }
    try {
      return await _evaluate(config, state, questions).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          _http.close(force: true);
          throw TimeoutException('决策请求超时');
        },
      );
    } on Object {
      if (_cancelled) throw const DecisionCancelled();
      rethrow;
    }
  }

  Future<Map<String, Map<String, Object?>>> _evaluate(
    ModelConfig config,
    Object state,
    Map<String, DecisionQuestion> questions,
  ) async {
    final request = await _http.postUrl(endpoint(config));
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${config.apiKey}',
    );
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'model': config.apiModel,
        'state': state,
        'questions': {
          for (final entry in questions.entries)
            entry.key: entry.value.toJson(),
        },
      }),
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (_cancelled) throw const DecisionCancelled();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}\n$body');
    }
    final decoded = jsonDecode(body) as Map;
    final answers = (decoded['answers'] as Map).cast<String, Object?>();
    final result = <String, Map<String, Object?>>{};
    for (final entry in questions.entries) {
      final answer = (answers[entry.key] as Map).cast<String, Object?>();
      if (answer['type'] != entry.value.type)
        throw FormatException('决策返回类型不匹配', body);
      switch (entry.value.type) {
        case 'choice':
          if (!(entry.value.criteria as Map).containsKey(answer['choice'])) {
            throw FormatException('决策返回了候选列表之外的选项', body);
          }
        case 'score':
          if (answer['score'] is! num) throw FormatException('评分结果无效', body);
        case 'noul':
          if (answer['noul'] is! num ||
              (answer['noul'] as num) < 0 ||
              (answer['noul'] as num) > 1) {
            throw FormatException('是非概率无效', body);
          }
      }
      result[entry.key] = answer;
    }
    return result;
  }

  void cancel() {
    _cancelled = true;
    _http.close(force: true);
  }

  void close() {
    _http.close(force: true);
  }
}
