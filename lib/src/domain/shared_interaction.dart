import 'interaction_expression.dart';

/// A round collects one submission per actor. Completion and state changes are
/// evaluated inside the caller's database transaction, never by the model.
class SharedInteraction {
  const SharedInteraction(this.definition, this.runtime);
  final Map<String, Object?> definition;
  final Map<String, Object?> runtime;

  static Map<String, Object?> initial(Map<String, Object?> definition) => {
    'round': 1,
    'version': 0,
    'phase': 'collecting',
    'state': {
      ...?definition['initial'] as Map?,
      ...?definition['roundInitial'] as Map?,
    },
    'submissions': <String, Object?>{},
  };

  int get round => runtime['round'] as int;
  int get version => runtime['version'] as int;
  String get phase => runtime['phase'] as String;
  Map<String, Object?> get state =>
      Map<String, Object?>.from(runtime['state'] as Map);
  Map<String, Map<String, Object?>> get submissions => {
    for (final entry in (runtime['submissions'] as Map).entries)
      entry.key as String: Map<String, Object?>.from(entry.value as Map),
  };
  bool get revealed =>
      definition['reveal'] != 'onComplete' || phase != 'collecting';
  bool get allowChange => definition['allowChange'] != false;

  Map<String, Object?> context({required bool closed}) => {
    'state': state,
    'submissions': submissions,
    'choices': submissions.values.toList(),
    'submittedCount': submissions.length,
    'round': round,
    'phase': phase,
    'closed': closed,
    'completed': phase == 'completed',
  };

  SharedInteraction submit(
    String actorId,
    String name,
    Map<String, Object?> button,
  ) {
    if (phase != 'collecting') throw StateError('本轮已结束，请查看结果');
    final eligible = definition['actors'] as List?;
    if (eligible != null && !eligible.contains(actorId))
      throw StateError('你不是本轮参与者');
    if (!allowChange && submissions.containsKey(actorId))
      throw StateError('已提交，等待本轮结束');
    return SharedInteraction(definition, {
      ...runtime,
      'version': version + 1,
      'submissions': {
        ...submissions,
        actorId: {
          'actorId': actorId,
          'name': name,
          'buttonId': button['id'],
          'label': button['label'],
          'value': button.containsKey('value') ? button['value'] : button['id'],
          if (button['selections'] != null) 'selections': button['selections'],
        },
      },
    }).settle(closed: false);
  }

  SharedInteraction settle({required bool closed}) {
    if (phase == 'closed' && !closed) {
      return SharedInteraction(definition, {
        ...runtime,
        'phase': 'collecting',
        'version': version + 1,
      }).settle(closed: false);
    }
    if (phase != 'collecting') return this;
    final ctx = context(closed: closed);
    final complete =
        evaluateInteraction(definition['completion'] ?? false, ctx) == true;
    if (!complete && !closed) return this;
    var nextState = state;
    if (complete) {
      for (final rule in definition['onComplete'] as List? ?? const []) {
        final current = {...ctx, 'state': nextState};
        if (evaluateInteraction(rule['when'] ?? true, current) == true) {
          nextState = {
            ...nextState,
            ...Map<String, Object?>.from(
              evaluateInteraction(rule['set'], current) as Map,
            ),
          };
        }
      }
    }
    return SharedInteraction(definition, {
      ...runtime,
      'phase': complete ? 'completed' : 'closed',
      'state': nextState,
      'version': version + 1,
    });
  }

  SharedInteraction nextRound(String actorId) {
    final eligible = definition['actors'] as List?;
    if (eligible != null && !eligible.contains(actorId))
      throw StateError('你不是本轮参与者');
    if (phase != 'completed') throw StateError('本轮尚未完成');
    return SharedInteraction(definition, {
      'round': round + 1,
      'version': version + 1,
      'phase': 'collecting',
      'state': {...state, ...?definition['roundInitial'] as Map?},
      'submissions': <String, Object?>{},
    });
  }

  Map<String, Object?> project(
    String actorId, {
    required bool closed,
    required bool choicesVisible,
    required bool summaryVisible,
    required List<Map<String, Object?>> distribution,
  }) => {
    'round': round,
    'phase': phase,
    'closed': closed,
    'completed': phase == 'completed',
    'submitted': submissions.containsKey(actorId),
    if (revealed && summaryVisible) 'submittedCount': submissions.length,
    'self': submissions[actorId],
    'revealed': revealed,
    'summaryVisible': summaryVisible,
    if (revealed && summaryVisible) 'distribution': distribution,
    // Shared values can contain choices or derived counts, so both policies apply.
    if (revealed && choicesVisible && summaryVisible) 'state': state,
    if (revealed && choicesVisible) ...{
      'submissions': submissions,
      'choices': submissions.values.toList(),
    },
  };
}
