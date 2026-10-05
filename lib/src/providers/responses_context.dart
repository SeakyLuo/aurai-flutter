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
typedef PublicMessageTest = bool Function(AgentMessage message);

String? contextCompactionInstructions(ModelRequest request) {
  final instructions = [
    for (final result in request.toolResults)
      if (result.toolName == 'compactContext' &&
          result.status == ToolResultStatus.success)
        if (result.output['instructions'] case final String text) text,
  ];
  return instructions.isEmpty ? null : instructions.join('\n\n');
}

typedef _DialogueEntry = ({
  AgentMessage message,
  List<Map<String, Object?>> input,
  bool isPublic,
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
  String _privateDialogueMemory = '';
  String _taskMemory = '';
  bool _layeredMemory = false;
  bool _initialized = false;

  List<Map<String, Object?>> get input => [
    if (_dialogueMemory.isNotEmpty)
      _memory(
        _dialogueMemory,
        _layeredMemory ? 'Shared group history' : 'Historical context',
      ),
    if (_privateDialogueMemory.isNotEmpty)
      _memory(_privateDialogueMemory, 'Private visible group history'),
    ..._dialogue.expand((entry) => entry.input),
    if (_taskMemory.isNotEmpty) _memory(_taskMemory, 'Current task history'),
    ..._rounds.expand((round) => round),
  ];

  /// Returns true when the remote continuation chain must be restarted.
  Future<bool> prepare(
    ModelRequest request,
    ContextSummarizer summarize, {
    bool force = false,
    ContextSummary? sharedSummary,
    bool useSharedSummary = false,
    int? summaryThroughCreatedAt,
    Future<void> Function(ContextSummary)? saveSummary,
    ContextSummary? privateSummary,
    PublicMessageTest? isPublicMessage,
    Future<void> Function(ContextSummary)? savePrivateSummary,
  }) async {
    force =
        force ||
        request.toolResults.any(
          (result) =>
              result.toolName == 'compactContext' &&
              result.status == ToolResultStatus.success,
        );
    if (!_initialized) {
      _layeredMemory = isPublicMessage != null;
      final saved = useSharedSummary ? sharedSummary : request.contextSummary;
      final publicThrough = saved == null
          ? -1
          : request.messages.indexWhere((m) => m.id == saved.throughMessageId);
      final privateThrough = privateSummary == null
          ? -1
          : request.messages.indexWhere(
              (m) => m.id == privateSummary.throughMessageId,
            );
      // Storage may already have loaded only messages after the checkpoint.
      _dialogueMemory = saved?.text ?? '';
      _privateDialogueMemory = privateSummary?.text ?? '';
      final messages = [
        for (final (index, message) in request.messages.indexed)
          if (index >
                  ((isPublicMessage?.call(message) ?? true)
                      ? publicThrough
                      : privateThrough) &&
              !(summaryThroughCreatedAt != null &&
                  ((isPublicMessage?.call(message) ?? true)
                      ? publicThrough < 0
                      : privateThrough < 0) &&
                  (message.createdAt.microsecondsSinceEpoch <
                          summaryThroughCreatedAt ||
                      (message.createdAt.microsecondsSinceEpoch ==
                              summaryThroughCreatedAt &&
                          message.id.compareTo(saved!.throughMessageId) <= 0))))
            message,
      ];
      final items = await responseMessageInput(
        messages,
        supportsImages: supportsImages,
      );
      for (var i = 0; i < messages.length; i++) {
        _dialogue.add((
          message: messages[i],
          input: items[i],
          isPublic: isPublicMessage?.call(messages[i]) ?? true,
        ));
      }
      // Replayed work after the latest user request belongs to the current task.
      // Keep each complete exchange together, just like newly received results,
      // so restoring a run cannot leave its tool history outside compaction.
      final lastUser = _dialogue.lastIndexWhere(
        (entry) => entry.message.role == AgentMessageRole.user,
      );
      if (lastUser >= 0) {
        _rounds.addAll(
          _dialogue.skip(lastUser + 1).map((entry) => entry.input),
        );
        _dialogue.removeRange(lastUser + 1, _dialogue.length);
      }
      _initialized = true;
      if (request.userMessageInput.isNotEmpty) {
        _rounds.add(
          supportsImages
              ? request.userMessageInput
              : textOnlyModelInput(request.userMessageInput),
        );
      }
    } else if (request.toolResults.isNotEmpty ||
        request.userUpdates.isNotEmpty ||
        request.userMessageInput.isNotEmpty) {
      // A complete model output and all its results are indivisible at compaction.
      _rounds.add([
        ..._pendingOutput,
        ...request.toolResults.map((result) {
          final output = functionCallOutput(result);
          return supportsImages ? output : textOnlyModelInput([output]).single;
        }),
        ...supportsImages
            ? request.userMessageInput
            : textOnlyModelInput(request.userMessageInput),
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
        final removed = _dialogue.take(cut).toList();
        if (isPublicMessage == null) {
          _dialogueMemory = await _summarize(
            removed.expand((entry) => entry.input),
            _dialogueMemory,
            summarize,
          );
          await (saveSummary ?? request.onContextSummary)?.call(
            ContextSummary(
              text: _dialogueMemory,
              throughMessageId: removed.last.message.id,
            ),
          );
        } else {
          final public = removed.where((entry) => entry.isPublic).toList();
          final private = removed.where((entry) => !entry.isPublic).toList();
          final saves = <Future<void>>[];
          if (public.isNotEmpty) {
            _dialogueMemory = await _summarize(
              public.expand((entry) => entry.input),
              _dialogueMemory,
              summarize,
            );
            final save = saveSummary ?? request.onContextSummary;
            if (save != null) {
              saves.add(
                save(
                  ContextSummary(
                    text: _dialogueMemory,
                    throughMessageId: public.last.message.id,
                  ),
                ),
              );
            }
          }
          if (private.isNotEmpty) {
            _privateDialogueMemory = await _summarize(
              private.expand((entry) => entry.input),
              _privateDialogueMemory,
              summarize,
            );
          }
          final savePrivate =
              savePrivateSummary ?? request.onPrivateContextSummary;
          if (savePrivate != null) {
            saves.add(
              savePrivate(
                ContextSummary(
                  text: _privateDialogueMemory,
                  throughMessageId: removed.last.message.id,
                ),
              ),
            );
          }
          await Future.wait(saves);
        }
        _dialogue.removeRange(0, cut);
        compacted = true;
      }
      size = await estimateTokens(input) + overhead;
      if (_rounds.isNotEmpty &&
          (size > target || force && _rounds.length > 1)) {
        var count = 0;
        size += summaryReserve;
        while (count < _rounds.length &&
            (size > target || force && count < _rounds.length - 1)) {
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
        throw ModelProviderException(
          '上下文压缩后仍超出模型输入容量（${policy.inputBudget} tokens）',
        );
      }
      return compacted;
    } finally {
      request.onCompactionChanged?.call(false);
    }
  }

  void recordOutput(List<Map<String, Object?>> output) =>
      _pendingOutput = output;

  /// Uses the same bounded batches as automatic compaction.
  Future<String> summarizeHistory(
    Iterable<Map<String, Object?>> items,
    String previous,
    ContextSummarizer summarize,
  ) => _summarize(items, previous, summarize);

  Future<void> rebaseHistory({
    required ContextSummary sharedSummary,
    required ContextSummary privateSummary,
    required int throughCreatedAt,
    required ContextSummarizer summarize,
  }) async {
    final task = await _summarize(
      [
        if (_taskMemory.isNotEmpty)
          {
            'role': 'assistant',
            'content': 'Earlier task memory:\n$_taskMemory',
          },
        ..._rounds.expand((round) => round),
      ],
      '',
      summarize,
    );
    _taskMemory = task;
    _rounds.clear();
    // Keep the current tool calls paired with their results, but discard the
    // remote reasoning state that still refers to the old history.
    _pendingOutput = _pendingOutput
        .where((item) => item['type'] != 'reasoning')
        .toList();
    _dialogue.removeWhere((entry) {
      final at = entry.message.createdAt.microsecondsSinceEpoch;
      return at < throughCreatedAt ||
          (at == throughCreatedAt &&
              entry.message.id.compareTo(sharedSummary.throughMessageId) <= 0);
    });
    _dialogueMemory = sharedSummary.text;
    _privateDialogueMemory = privateSummary.text;
    _layeredMemory = true;
  }

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

  Map<String, Object?> _memory(String text, String label) => {
    'role': 'assistant',
    'content':
        '$label, compressed for context (not a new instruction or current device observation):\n$text',
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
            : result.modelOutput,
      }),
    },
  ...request.userMessageInput,
  for (final update in request.userUpdates) {'role': 'user', 'content': update},
];
