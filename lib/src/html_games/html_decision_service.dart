import '../providers/decision_client.dart';

/// Page-scoped decisions reuse the native model selection and credentials.
class HtmlDecisionService {
  final _jobs = <int, DecisionClient>{};

  Future<Map<String, Object?>> invoke(int id, Map<String, Object?> args) async {
    final client = DecisionClient();
    _jobs[id] = client;
    try {
      final config = await DecisionClient.configuration();
      if (client.cancelled) return {'cancelled': true};
      if (args['operation'] == 'decisionStatus') {
        return {
          'available': config != null,
          if (config != null) 'model': config.model,
        };
      }
      if (config == null) throw StateError('请先在模型设置中选择默认决策模型');
      final raw = (args['questions'] as Map).cast<String, Object?>();
      final questions = <String, DecisionQuestion>{};
      for (final entry in raw.entries) {
        final question = (entry.value as Map).cast<String, Object?>();
        questions[entry.key] = switch (question['type']) {
          'choice' => DecisionQuestion.choice(
            question['instructions']!,
            (question['criteria'] as Map).cast<String, Object?>(),
          ),
          'noul' => DecisionQuestion.noul(question['instructions']!),
          'score' => DecisionQuestion.score(
            question['instructions']!,
            question['criteria'] as List<Object?>,
          ),
          _ => throw ArgumentError('不支持的决策问题类型'),
        };
      }
      final answers = await client.evaluate(
        config: config,
        state: args['state']!,
        questions: questions,
      );
      return {'answers': answers, 'model': config.model};
    } on DecisionCancelled {
      return {'cancelled': true};
    } on Object catch (error) {
      // The bridge is the execution boundary; retain the original failure.
      return {'error': '$error', 'code': 'decision_error'};
    } finally {
      client.close();
      _jobs.remove(id);
    }
  }

  void cancel(int id) => _jobs[id]?.cancel();

  void cancelAll() {
    for (final client in _jobs.values) {
      client.cancel();
    }
  }
}
