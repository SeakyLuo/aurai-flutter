import '../domain/model_provider.dart';
import 'model_context_limits.dart';
import 'model_image_input.dart';
import 'response_message_input.dart';
import 'responses_context.dart' show estimateTokens, functionCallOutput;
import 'shared_responses_context.dart';

/// A local sliding window; original messages and tool results stay in storage.
class ResponseWindow {
  ResponseWindow(
    this.limits, {
    required this.systemPrompt,
    required this.supportsImages,
    this.sharedContext,
  });
  final SharedResponsesContext? sharedContext;
  int _revision = 0;
  final ModelContextLimits limits;
  final String systemPrompt;
  final bool supportsImages;
  final _exchanges = <List<Map<String, Object?>>>[];
  List<Map<String, Object?>> _pendingOutput = [];
  bool _initialized = false;
  String? refreshedContext;
  Future<({Object? error, StackTrace? stack})>? _backgroundOrganization;

  List<Map<String, Object?>> get input => _exchanges.expand((e) => e).toList();

  /// A changed window invalidates the server's previous_response_id chain.
  Future<bool> prepare(ModelRequest request) async {
    refreshedContext = null;
    final revision = sharedContext?.revision ?? 0;
    final checkpointChanged = _initialized && revision != _revision;
    // Explicit checkpoints use the same save-before-evict boundary.
    _revision = revision;
    if (!_initialized) {
      final history = await responseMessageInput(
        request.messages,
        supportsImages: supportsImages,
      );
      for (final items in history) {
        _appendHistory(items);
      }
      _initialized = true;
    }
    if (_pendingOutput.isNotEmpty ||
        request.toolResults.isNotEmpty ||
        request.userUpdates.isNotEmpty ||
        request.userMessageInput.isNotEmpty) {
      _exchanges.add([
        ..._pendingOutput,
        for (final result in request.toolResults)
          ..._forModel([functionCallOutput(result)]),
        ..._forModel(request.userMessageInput),
        for (final text in request.userUpdates)
          {'role': 'user', 'content': text},
      ]);
      _pendingOutput = [];
    }
    final overhead = await estimateTokens({
      'instructions': '$systemPrompt\n${request.personalContext}',
      'tools': [
        for (final tool in request.tools)
          {
            'name': tool.name,
            'description': tool.modelDescription,
            'parameters': tool.modelInputSchema,
          },
      ],
      'capabilities': request.capabilities.map((c) => c.reason).toList(),
      'responseSchema': request.responseSchema,
    });
    final costs = await Future.wait(_exchanges.map(estimateTokens));
    var size = overhead + costs.fold<int>(0, (a, b) => a + b);
    if (size <= limits.compactThreshold &&
        size >= limits.compactThreshold * .85 &&
        _backgroundOrganization == null &&
        request.organizeTask != null) {
      _backgroundOrganization = request.organizeTask!().then(
        (_) => (error: null, stack: null),
        onError: (Object error, StackTrace stack) =>
            (error: error, stack: stack),
      );
    }
    var removed = 0;
    // Calls and their results are removed as one complete exchange.
    final needsRoom = size > limits.compactThreshold || checkpointChanged;
    while (removed < _exchanges.length - 1 &&
        needsRoom &&
        (size > limits.compactTarget || checkpointChanged)) {
      size -= costs[removed++];
    }
    if (removed > 0) {
      final organize = request.organizeTask;
      if (organize != null) {
        request.onCompactionChanged?.call(true);
        try {
          final background = await _backgroundOrganization;
          if (background?.error != null) {
            Error.throwWithStackTrace(background!.error!, background.stack!);
          }
          // Include complete rounds finished after the background snapshot.
          refreshedContext = await organize();
          _backgroundOrganization = null;
        } finally {
          request.onCompactionChanged?.call(false);
        }
        size +=
            await estimateTokens(refreshedContext) -
            await estimateTokens(request.personalContext);
      }
      if (size <= limits.inputBudget) _exchanges.removeRange(0, removed);
    }
    if (size > limits.inputBudget) {
      throw ModelProviderException(
        '最新消息或完整工具返回超出模型输入容量（${limits.inputBudget} tokens），请缩小本次输入或工具输出范围',
      );
    }
    return removed > 0 || checkpointChanged;
  }

  List<Map<String, Object?>> _forModel(List<Map<String, Object?>> items) =>
      supportsImages ? items : textOnlyModelInput(items);

  void _appendHistory(List<Map<String, Object?>> items) {
    var exchange = <Map<String, Object?>>[];
    final pending = <String>{};
    for (final item in items) {
      final type = item['type'];
      // Keep reasoning and assistant output with the calls they precede.
      if (pending.isEmpty &&
          exchange.isNotEmpty &&
          (item['role'] == 'user' ||
              type == 'reasoning' ||
              exchange.last['type'] == 'function_call_output')) {
        _exchanges.add(exchange);
        exchange = [];
      }
      exchange.add(item);
      if (type == 'function_call') pending.add(item['call_id']! as String);
      if (type == 'function_call_output') pending.remove(item['call_id']);
    }
    if (exchange.isNotEmpty) _exchanges.add(exchange);
  }

  void recordOutput(List<Map<String, Object?>> output) =>
      _pendingOutput = output;
}
