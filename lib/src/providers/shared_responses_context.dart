import 'dart:async';
import '../domain/agent_models.dart';
import '../domain/context_summary.dart';
import '../domain/model_provider.dart';
import 'responses_context.dart';

/// Serialize public-history checkpoints, while members keep private tool rounds.
class SharedResponsesContext {
  SharedResponsesContext(
    ContextSummary? initial,
    Map<String, ContextSummary> privateSummaries,
  ) : summary = initial,
      _initial = initial,
      privateSummaries = privateSummaries;

  final ContextSummary? _initial;

  ContextSummary? summary;
  final Map<String, ContextSummary> privateSummaries;
  Future<void> _tail = Future.value();

  Future<bool> prepare(
    ResponsesContext context,
    ModelRequest request,
    ContextSummarizer summarize,
    String senderId,
  ) async {
    if (context.initialized) {
      // A running member may compact its own older snapshot and tool exchanges,
      // but must not overwrite the group's newer shared checkpoint.
      return context.prepare(
        request,
        summarize,
        saveSummary: (_) async {},
        privateSummary: privateSummaries[senderId],
        isPublicMessage: _isPublic,
        savePrivateSummary: (next) async {
          await request.onPrivateContextSummary?.call(next);
          privateSummaries[senderId] = next;
        },
      );
    }
    final previous = _tail;
    final finished = Completer<void>();
    _tail = finished.future;
    await previous;
    try {
      final current = summary;
      final canAdvance =
          current == null ||
          current.throughMessageId == _initial?.throughMessageId ||
          request.messages.any((m) => m.id == current.throughMessageId);
      return await context.prepare(
        request,
        summarize,
        sharedSummary: canAdvance ? current : _initial,
        useSharedSummary: true,
        privateSummary: privateSummaries[senderId],
        isPublicMessage: _isPublic,
        saveSummary: (next) async {
          if (!canAdvance) return;
          await request.onContextSummary?.call(next);
          summary = next;
        },
        savePrivateSummary: (next) async {
          await request.onPrivateContextSummary?.call(next);
          privateSummaries[senderId] = next;
        },
      );
    } finally {
      finished.complete();
    }
  }

  bool _isPublic(AgentMessage message) => !message.hasRestrictedAudience;
}
