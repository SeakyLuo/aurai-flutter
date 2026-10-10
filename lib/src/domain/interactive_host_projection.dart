import 'interactive_message.dart';

/// The single data boundary for generic DSL views and the AI read tool.
Map<String, Object?> interactiveHostProjection(
  InteractiveMessage card,
  String actor,
) {
  card.requireViewer(actor);
  final view = card.hasInteraction
      ? card.interactionView(actor)
      : <String, Object?>{};
  final self = view['self'] as Map? ?? card.participants[actor];
  final eligible =
      (card.interaction['actors'] as List?)?.contains(actor) ?? true;
  final submitted =
      view['submitted'] == true || (!card.shared && self?['value'] != null);
  final allowChange = card.shared
      ? card.engine.allowChange
      : card
            .viewFor(actor)
            .buttons
            .any(
              (button) =>
                  button['action'] == 'submit' && button['repeatable'] == true,
            );
  final collecting =
      !card.closed &&
      !card.collectionPaused &&
      (!card.shared || card.engine.phase == 'collecting');
  final summaryVisible = view['summaryVisible'] == true;
  final choicesVisible = card.snapshotView != null
      ? view.containsKey('submissions')
      : card.visible('visibility', actor: actor);
  return {
    'eligible': eligible,
    'submitted': submitted,
    'closed': card.closed,
    'collectionPaused': card.collectionPaused,
    'completed': card.completed,
    'canSubmit': eligible && collecting && (!submitted || allowChange),
    'canEdit': eligible && collecting && submitted && allowChange,
    'summaryVisible': summaryVisible,
    'responsesVisible': choicesVisible,
    'submittedCount': summaryVisible ? view['submittedCount'] : null,
    'eligibleCount': summaryVisible ? view['eligibleCount'] : null,
    'answers': self?['answers'] ?? const <Object?>[],
    'responses': choicesVisible
        ? [
            for (final entry in (view['choices'] as List? ?? const []))
              <String, Object?>{
                'name': entry['name'],
                'answers': entry['answers'] ?? const <Object?>[],
                'label': entry['label'],
              },
          ]
        : const [],
    'distribution': summaryVisible
        ? view['distribution'] ?? const []
        : const [],
    'metrics': summaryVisible
        ? view['formMetrics'] ?? const <Object?>[]
        : const <Object?>[],
  };
}
