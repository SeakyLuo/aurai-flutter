import 'dart:async';

import '../domain/tool_models.dart';

class UserQuestionOption {
  const UserQuestionOption({this.title, required this.content});
  final String? title;
  final String content;

  factory UserQuestionOption.fromValue(Object value) {
    if (value is String) return UserQuestionOption(content: value);
    final option = value as Map;
    return UserQuestionOption(
      title: option['title'] as String?,
      content: option['content'] as String,
    );
  }

  String get answer => title == null ? content : '$title：$content';
}

class UserQuestion {
  UserQuestion({
    required this.conversationId,
    required this.question,
    required this.options,
    required this.allowCustomAnswer,
    this.title,
    this.customAnswerPlaceholder,
    this.isUserAction = false,
  });
  final String conversationId;
  final String? title;
  final String question;
  final List<Object> options;
  final bool allowCustomAnswer;
  final String? customAnswerPlaceholder;
  final bool isUserAction;
  UserQuestionOption optionAt(int index) =>
      UserQuestionOption.fromValue(options[index]);
  final result = Completer<Map<String, Object?>>();
  String draft = '';
  int? selected;

  void answer({bool skipped = false}) {
    if (result.isCompleted) return;
    final text = draft.trim();
    result.complete({
      'skipped': skipped,
      if (isUserAction) ...{
        'cancelled': skipped || (text.isEmpty && selected == 1),
        'reportedCompleted': !skipped && text.isEmpty && selected == 0,
      },
      if (!skipped)
        'answer': text.isNotEmpty ? text : optionAt(selected!).answer,
    });
  }
}

class AskUserTool implements AgentTool, RuntimeCapabilityAgentTool {
  AskUserTool(this.conversationId, this.onQuestion);
  final String conversationId;
  final void Function(UserQuestion?) onQuestion;
  UserQuestion? _pending;
  final _updates = <ToolResult>[];
  bool get hasPending => _pending != null;
  bool get hasUpdates => _updates.isNotEmpty;

  List<ToolResult> takeUpdates() {
    final updates = List<ToolResult>.of(_updates);
    _updates.clear();
    return updates;
  }

  Future<void> waitForPending() async {
    await _pending?.result.future;
  }

  Future<Map<String, Object?>> waitForUserAction(String instruction) async {
    final question = UserQuestion(
      conversationId: conversationId,
      question: instruction,
      options: const ['已完成', '取消'],
      allowCustomAnswer: true,
      isUserAction: true,
    );
    _pending = question;
    onQuestion(question);
    try {
      return await question.result.future.timeout(const Duration(days: 1));
    } on TimeoutException {
      await cancel();
      return {'cancelled': true, 'timedOut': true};
    } finally {
      _pending = null;
      onQuestion(null);
    }
  }

  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'askUser',
    waitsForUser: true,
    description:
        'Ask one concise question when a user preference or missing information is needed. title is an optional short heading shown instead of the generic question label. Present up to four options, or no options for a free-text question. Each option may be plain text or an object with a short title and supporting content. Set an option title to null for content only; avoid repeating the option title in its content. Set allowCustomAnswer=true only when the user may need to write an answer outside the provided options. A question with no options always accepts free text. customAnswerPlaceholder optionally provides a concise hint for that input; omit it to use the app default. The user may answer or skip. waitForResponse=true or null waits for the answer. Set false only when independent work can continue without it: returns pending immediately and the actual answer arrives as a user update on a later model turn. Do not perform answer-dependent work or claim a final outcome while pending. Never infer an answer from skipping. Do not repeat the question in prose before calling. Incorporate later answers or skips before finalizing; a skip is not consent. For skipped optional details, use a reasonable stated assumption; otherwise explain what is still needed. Do not use this for device permission approval.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'waitForResponse': {
          'type': ['boolean', 'null'],
          'description':
              'true or null: wait for an answer (default). false: continue independent work while the question remains open.',
        },
        'question': {'type': 'string', 'minLength': 1, 'maxLength': 600},
        'allowCustomAnswer': {
          'type': 'boolean',
          'description':
              'Whether to show a free-text answer field alongside the options. Set true for questions without options.',
        },
        'customAnswerPlaceholder': {
          'type': 'string',
          'minLength': 1,
          'maxLength': 60,
          'description':
              'Optional concise placeholder for the free-text answer field. Omit to use the app default.',
        },
        'title': {
          'type': 'string',
          'minLength': 1,
          'maxLength': 20,
          'description': 'Optional short heading shown above the question.',
        },
        'options': {
          'type': 'array',
          'items': {
            'anyOf': [
              {'type': 'string', 'minLength': 1, 'maxLength': 240},
              {
                'type': 'object',
                'properties': {
                  'title': {
                    'type': ['string', 'null'],
                    'minLength': 1,
                    'maxLength': 60,
                  },
                  'content': {
                    'type': 'string',
                    'minLength': 1,
                    'maxLength': 240,
                  },
                },
                'required': ['title', 'content'],
                'additionalProperties': false,
              },
            ],
          },
          'maxItems': 4,
        },
      },
      'required': [
        'question',
        'options',
        'allowCustomAnswer',
        'waitForResponse',
      ],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'user.question',
    executionTimeout: Duration(days: 1),
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    if (_pending case final existing?) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: {
          'pending': true,
          'question': existing.question,
          'newQuestionShown': false,
          'next':
              'The earlier question is still open. Do not replace it or assume an answer.',
        },
      );
    }
    final question = UserQuestion(
      conversationId: conversationId,
      title: call.arguments['title'] as String?,
      customAnswerPlaceholder:
          call.arguments['customAnswerPlaceholder'] as String?,
      question: call.arguments['question'] as String,
      options: List<Object>.from(call.arguments['options'] as List),
      allowCustomAnswer:
          (call.arguments['options'] as List).isEmpty ||
          call.arguments['allowCustomAnswer'] == true,
    );
    _pending = question;
    onQuestion(question);
    if (call.arguments['waitForResponse'] == false) {
      question.result.future.then((answer) {
        _updates.add(
          ToolResult(
            callId: call.id,
            toolName: call.name,
            status: answer['cancelled'] == true
                ? ToolResultStatus.cancelled
                : ToolResultStatus.success,
            output: {'question': question.question, ...answer},
          ),
        );
        if (identical(_pending, question)) {
          _pending = null;
          onQuestion(null);
        }
      });
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: {
          'pending': true,
          'question': question.question,
          'next':
              'Continue only independent work. The answer will arrive in a user update; do not treat pending as consent.',
        },
      );
    }
    try {
      final answer = await question.result.future;
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: answer['cancelled'] == true
            ? ToolResultStatus.cancelled
            : ToolResultStatus.success,
        output: {'question': question.question, ...answer},
      );
    } finally {
      _pending = null;
      onQuestion(null);
    }
  }

  @override
  Future<void> cancel() async {
    final question = _pending;
    if (question != null && !question.result.isCompleted) {
      question.result.complete({'cancelled': true});
    }
  }
}
