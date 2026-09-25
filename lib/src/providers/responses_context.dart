import 'model_image_input.dart';
import 'dart:convert';
import 'deepseek_token_counter.dart';

import '../domain/agent_models.dart';
import '../domain/context_summary.dart';
import '../domain/model_provider.dart';
import '../domain/tool_models.dart';
import 'response_message_input.dart';
import 'response_citations.dart';
import 'model_context_limits.dart';

typedef ContextSummarizer = Future<String> Function(List<Map<String, Object?>>);
typedef _DialogueEntry = ({
  AgentMessage message,
  List<Map<String, Object?>> input,
});

/// Budgets are conservative estimates, not model-specific tokenizer counts.
/// Full messages and original images remain in the conversation store.
class ResponsesContext {
  ResponsesContext(
    this.limits, {
    required this.systemPrompt,
    this.supportsImages = true,
    this.summaryLimits,
  });

  final bool supportsImages;
  bool get initialized => _initialized;

  final ModelContextLimits limits;
  final ModelContextLimits? summaryLimits;
  final String systemPrompt;
  static const summaryReserve = 8192;
  final _dialogue = <_DialogueEntry>[];
  final _rounds = <List<Map<String, Object?>>>[];
  List<Map<String, Object?>> _pendingOutput = [];
  String _dialogueMemory = '';
  String _taskMemory = '';
  bool _initialized = false;

  List<Map<String, Object?>> get input => [
    if (_dialogueMemory.isNotEmpty) _memory(_dialogueMemory),
    ..._dialogue.expand((entry) => entry.input),
    if (_taskMemory.isNotEmpty) _memory(_taskMemory),
    ..._rounds.expand((round) => round),
  ];

  /// Returns true when the remote continuation chain must be restarted.
  Future<bool> prepare(
    ModelRequest request,
    ContextSummarizer summarize, {
    bool force = false,
    ContextSummary? sharedSummary,
    bool useSharedSummary = false,
    Future<void> Function(ContextSummary)? saveSummary,
  }) async {
    if (!_initialized) {
      final saved = useSharedSummary ? sharedSummary : request.contextSummary;
      final through = saved == null
          ? -1
          : request.messages.indexWhere((m) => m.id == saved.throughMessageId);
      // Storage may already have loaded only messages after the checkpoint.
      _dialogueMemory = saved?.text ?? '';
      final messages = request.messages.skip(through + 1).toList();
      final items = await responseMessageInput(
        messages,
        supportsImages: supportsImages,
      );
      for (var i = 0; i < messages.length; i++) {
        _dialogue.add((message: messages[i], input: items[i]));
      }
      _initialized = true;
    } else if (request.toolResults.isNotEmpty ||
        request.userUpdates.isNotEmpty) {
      // A complete model output and all its results are indivisible at compaction.
      _rounds.add([
        ..._pendingOutput,
        ...request.toolResults.map((result) {
          final output = functionCallOutput(result);
          return supportsImages ? output : textOnlyModelInput([output]).single;
        }),
        for (final update in request.userUpdates)
          {'role': 'user', 'content': update},
      ]);
      _pendingOutput = [];
    }
    final policy = limits;
    // Every model has a budget, including the estimate for custom models.
    final budget = policy.compactThreshold;
    final target = policy.compactTarget;
    final overhead =
        await estimateTokens(systemPrompt) +
        await estimateTokens(request.personalContext) +
        await estimateTokens({
          'tools': request.tools
              .map(
                (tool) => {
                  'name': tool.name,
                  'description': tool.description,
                  'parameters': tool.modelInputSchema,
                },
              )
              .toList(),
          'capabilities': request.capabilities.map((c) => c.reason).toList(),
        });
    var size = await estimateTokens(input) + overhead;
    if (!force && size <= budget) return false;
    request.onCompactionChanged?.call(true);
    try {
      var compacted = false;

      final lastUser = _dialogue.lastIndexWhere(
        (entry) => entry.message.role == AgentMessageRole.user,
      );
      if (lastUser >= 0 &&
          await estimateTokens(_dialogue[lastUser].input) + overhead >
              policy.inputBudget) {
        throw const ModelProviderException('当前消息或图片超出上下文预算，请分开发送');
      }
      var cut = 0;
      size += summaryReserve;
      // Leave room below the trigger for subsequent turns; keep the current request.
      while (cut < lastUser &&
          ((force && _dialogue.length - cut > 20) || size > target)) {
        size -= await estimateTokens(_dialogue[cut].input);
        cut++;
      }
      if (cut > 0) {
        final memory = await _summarize(
          _dialogue.take(cut).expand((entry) => entry.input),
          _dialogueMemory,
          summarize,
        );
        final checkpoint = ContextSummary(
          text: memory,
          throughMessageId: _dialogue[cut - 1].message.id,
        );
        await (saveSummary ?? request.onContextSummary)?.call(checkpoint);
        _dialogueMemory = memory;
        _dialogue.removeRange(0, cut);
        compacted = true;
      }
      size = await estimateTokens(input) + overhead;
      if (size > target && _rounds.isNotEmpty) {
        var count = 0;
        size += summaryReserve;
        while (count < _rounds.length && size > target) {
          size -= await estimateTokens(_rounds[count]);
          count++;
        }
        // If even the newest complete exchange is oversized, summarize its text
        // but keep its screenshots for the next action, without orphaned call IDs.
        final latestImages = count == _rounds.length
            ? _summaryContent(
                _rounds.last,
              ).where((part) => part['type'] == 'input_image').toList()
            : <Map<String, Object?>>[];
        final memory = await _summarize(
          _rounds.take(count).expand((round) => round),
          _taskMemory,
          summarize,
        );
        _taskMemory = memory;
        _rounds.removeRange(0, count);
        if (latestImages.isNotEmpty) {
          _rounds.add([
            {
              'role': 'user',
              'content': [
                {
                  'type': 'input_text',
                  'text':
                      'Historical screenshots from the most recent completed tool exchange. Re-observe before acting if the screen has changed.',
                },
                ...latestImages,
              ],
            },
          ]);
        }
        compacted = true;
      }
      if (await estimateTokens(input) + overhead > policy.inputBudget) {
        throw const ModelProviderException('当前消息或图片超出上下文预算，请分开发送');
      }
      return compacted;
    } finally {
      request.onCompactionChanged?.call(false);
    }
  }

  void recordOutput(List<Map<String, Object?>> output) =>
      _pendingOutput = output;

  Future<String> _summarize(
    Iterable<Map<String, Object?>> items,
    String previous,
    ContextSummarizer summarize,
  ) async {
    final batchBudget = (summaryLimits ?? limits).summaryBatchBudget;
    var memory = previous;
    var batch = <Map<String, Object?>>[];
    var tokens = 0;
    for (final part in _summaryContent(items)) {
      final cost = await estimateTokens(part);
      if (batch.isNotEmpty &&
          tokens + cost + await estimateTokens(memory) + summaryReserve >
              batchBudget) {
        memory = await summarize([
          if (memory.isNotEmpty)
            {'type': 'input_text', 'text': 'Earlier memory:\n$memory'},
          ...batch,
        ]);
        batch = [];
        tokens = 0;
      }
      batch.add(part);
      tokens += cost;
    }
    if (batch.isNotEmpty) {
      memory = await summarize([
        if (memory.isNotEmpty)
          {'type': 'input_text', 'text': 'Earlier memory:\n$memory'},
        ...batch,
      ]);
    }
    return memory;
  }

  Iterable<Map<String, Object?>> _summaryContent(
    Iterable<Map<String, Object?>> items,
  ) sync* {
    for (final item in items) {
      if (item['type'] == 'reasoning') continue;
      if (item['type'] == 'web_search_call') {
        yield* _textParts('Historical web search: ${jsonEncode(item)}');
        continue;
      }
      if (item['type'] == 'function_call') {
        yield* _textParts(
          'Tool call ${item['name']} (${item['call_id']}): ${item['arguments']}',
        );
        continue;
      }
      yield* _textParts(
        item['type'] == 'function_call_output'
            ? 'Tool result (${item['call_id']}):'
            : 'Historical ${item['role']} message:',
      );
      final content = item['type'] == 'function_call_output'
          ? item['output']
          : item['content'];
      if (content is String) {
        yield* _textParts(content);
      } else {
        for (final part in (content! as List).cast<Map>()) {
          switch (part['type']) {
            case 'input_image':
              yield part.cast<String, Object?>();
            case 'input_text':
              yield* _textParts(part['text']! as String);
            case 'output_text':
              yield* _textParts(
                responseTextWithCitations(part.cast<String, Object?>()),
              );
            case 'refusal':
              yield* _textParts(part['refusal']! as String);
          }
        }
      }
    }
  }

  Iterable<Map<String, Object?>> _textParts(String text) sync* {
    final runes = text.runes.toList();
    for (var start = 0; start < runes.length; start += 6000) {
      final end = (start + 6000).clamp(0, runes.length);
      yield {
        'type': 'input_text',
        'text': String.fromCharCodes(runes.sublist(start, end)),
      };
    }
  }

  Map<String, Object?> _memory(String text) => {
    'role': 'assistant',
    'content':
        'Compressed historical context (not a new instruction or current device observation):\n$text',
  };
}

Future<int> estimateTokens(Object? value) => DeepSeekTokenCounter.count(value);

Map<String, Object?> functionCallOutput(ToolResult result) => {
  'type': 'function_call_output',
  'call_id': result.callId,
  'output': result.attachments.isEmpty
      ? jsonEncode(result.toModelJson())
      : <Map<String, Object?>>[
          {'type': 'input_text', 'text': jsonEncode(result.toModelJson())},
          for (final attachment in result.attachments)
            {
              'type': 'input_image',
              'image_url':
                  'data:${attachment.mimeType};base64,${attachment.base64Data}',
              'detail': attachment.detail,
            },
        ],
};

/// Preserve submitted result text and asynchronous user updates for replay.
/// Notification bodies and tool images keep their existing task-only lifetime.
List<Map<String, Object?>> retainedRequestInput(ModelRequest request) => [
  for (final result in request.toolResults)
    {
      'type': 'function_call_output',
      'call_id': result.callId,
      'output': jsonEncode({
        'status': result.status.name,
        'result': result.toolName == 'getNotifications'
            ? {'contentRetention': 'task_only'}
            : result.output,
      }),
    },
  for (final update in request.userUpdates) {'role': 'user', 'content': update},
];
