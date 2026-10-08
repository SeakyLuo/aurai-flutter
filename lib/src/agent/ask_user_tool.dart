import '../domain/question_reply_signals.dart';
import '../domain/question_batch.dart';
import 'question_batch_schema.dart';
import 'deferred_tool.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../domain/tool_models.dart';
import '../domain/message_sender.dart';

class UserQuestionOption {
  const UserQuestionOption({this.title, required this.content, this.messageId});
  final String? title;
  final String? messageId;
  final String content;

  factory UserQuestionOption.fromSelection(Map option) => UserQuestionOption(
    content: option['label'] as String,
    messageId: (option['content'] as Map?)?['messageId'] as String?,
  );

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
  static final activeCards = <String, UserQuestion>{};
  UserQuestion({
    required this.conversationId,
    required this.sender,
    required this.question,
    required this.options,
    required this.allowCustomAnswer,
    this.batch,
    this.title,
    this.customAnswerPlaceholder,
    this.callId,
    this.executionRunId,
    Duration timeout = responseTimeout,
  }) : expiresAt = DateTime.now().add(timeout) {
    _timeout = Timer(timeout, () {
      result.complete({'cancelled': true, 'timedOut': true});
    });
    result.future.then((_) => _timeout.cancel());
  }
  static const responseTimeout = Duration(days: 1);
  final QuestionBatch? batch;
  String? messageId;
  Future<void> Function(Map<String, Object?>)? persistAnswer;
  bool _submitting = false;
  Future<void> submitBatch(Map<String, Object?> answers) async {
    if (result.isCompleted || _submitting) return;
    _submitting = true;
    try {
      await persistAnswer!(answers);
    } finally {
      _submitting = false;
    }
  }

  final answers = <String, Object?>{};
  int questionIndex = 0;
  final String? callId;
  final String? executionRunId;
  final DateTime expiresAt;
  late final Timer _timeout;
  final sheetVisible = ValueNotifier(false);
  final String conversationId;
  final MessageSender sender;
  final String? title;
  final String question;
  final List<Object> options;
  final bool allowCustomAnswer;
  final String? customAnswerPlaceholder;
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
      if (!skipped)
        'answer': text.isNotEmpty ? text : optionAt(selected!).answer,
    });
  }
}

class AskUserTool implements DeferredAgentTool, RuntimeCapabilityAgentTool {
  AskUserTool(
    this.conversationId,
    this.onQuestion, {
    required this.sender,
    this.executionRunId,
  });
  final String? executionRunId;
  final String conversationId;
  final MessageSender sender;
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

  Future<Map<String, Object?>> Function(Map<String, Object?> definition)?
  publishCard;
  bool defaultToCard = false;
  bool usesMessageCard(Map<String, Object?> arguments) => defaultToCard;
  late Future<void> Function(String messageId, Map<String, Object?> answers)
  submitCard;

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'askUser',
    waitsForUser: true,
    description:
        'Ask the user 1–10 independent questions, preferably 3–5. Use one batch only when the questions do not depend on earlier answers. Do not repeat questions or selection instructions in prose. All questions are recorded as native question messages and open the same answer sheet. In private and group chats the tool returns immediately; submission later notifies you with the answers. Continue only independent work until then. In tasks this opens a question sheet and waits for submission; closing the sheet only hides it. A skipped question is not consent. For manual steps, open the relevant page first and verify actual state after the answer. Never use this for device permission approval.',
    inputSchema: const {
      'type': 'object',
      'properties': {'questions': questionBatchSchema},
      'required': ['questions'],
      'additionalProperties': false,
    },
    safety: ToolSafety.lowRisk,
    capabilityId: 'user.question',
    executionTimeout: UserQuestion.responseTimeout,
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final batch = QuestionBatch(call.arguments['questions'] as List)
      ..validate();
    if (_pending != null) throw StateError('上一组问题仍在等待回答');
    {
      final publish = publishCard!;
      final sent = await publish({
        'title': batch.questions.length == 1
            ? '问题'
            : '${batch.questions.length} 个问题',
        'body': '',
        'buttons': [
          {
            'id': 'answer',
            'label': '提交回答',
            'action': 'submit',
            'style': 'primary',
            'repeatable': false,
            'questions': batch.questions,
          },
        ],
        'interaction': {
          'actors': ['user:local'],
          'allowChange': false,
          'completion': {
            'op': 'eq',
            'args': [
              {'ref': 'submittedCount'},
              1,
            ],
          },
          'views': <Object?>[],
        },
        'participation': {
          'visibility': 'public',
          'summaryVisibility': 'public',
          'showHistory': false,
          'callbackEvents': ['complete'],
        },
      });
      final first = batch.questions.first;
      final question = UserQuestion(
        batch: batch,
        callId: call.id,
        executionRunId: executionRunId,
        conversationId: sent['conversationId'] as String,
        sender: sender,
        question: first['question'] as String,
        options: const [],
        allowCustomAnswer: true,
      );
      final id = sent['messageId'] as String;
      question.messageId = id;
      question.persistAnswer = (answers) async {
        await submitCard(id, answers);
        if (!question.result.isCompleted) {
          question.result.complete({'answers': batch.resolve(answers)});
        }
      };
      UserQuestion.activeCards[id] = question;
      question.result.future.then((_) {
        UserQuestion.activeCards.remove(id);
        QuestionReplySignals.release(id);
      });
      if (!defaultToCard) _pending = question;
      QuestionReplySignals.wait(id, blocking: !defaultToCard).then((answer) {
        if (!question.result.isCompleted) question.result.complete(answer);
      });
      onQuestion(question);
      if (defaultToCard) {
        question.result.future.then((_) => onQuestion(null));
        return ToolResult(
          callId: call.id,
          toolName: call.name,
          status: ToolResultStatus.success,
          output: {
            ...sent,
            'awaitingResponse': true,
            'next':
                'The question is recorded in chat and opens the answer sheet. Do not repeat it. Submitted answers arrive through the completion callback.',
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
          output: {...sent, ...answer},
        );
      } finally {
        QuestionReplySignals.release(id);
        _pending = null;
        onQuestion(null);
      }
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
