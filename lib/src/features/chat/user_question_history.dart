import 'dart:convert';

import 'package:flutter/material.dart';

import '../../agent/ask_user_tool.dart';
import '../../domain/agent_models.dart';
import 'user_question_option_tile.dart';
import '../../domain/question_batch.dart';
import 'question_batch_form.dart';

class UserQuestionHistory extends StatelessWidget {
  const UserQuestionHistory({
    super.key,
    required this.requestJson,
    required this.resultJson,
    required this.status,
  });

  final String? requestJson;
  final String? resultJson;
  final AgentStepStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final request = requestJson == null
        ? null
        : jsonDecode(requestJson!) as Map;
    final result = resultJson == null ? null : jsonDecode(resultJson!) as Map;
    if (request?['questions'] case final List questions) {
      return _BatchHistory(questions: questions, result: result);
    }
    final options = request == null
        ? const <UserQuestionOption>[]
        : (request['options'] as List)
              .map((value) => UserQuestionOption.fromValue(value as Object))
              .toList();
    final answer = result?['answer'] as String?;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            request == null ? '此记录未保存问题内容' : request['question'] as String,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: UserQuestionOptionTile(
                option: options[i],
                number: i + 1,
                selected: answer == options[i].answer,
                onTap: null,
              ),
            ),
          if (answer != null &&
              !options.any((option) => option.answer == answer)) ...[
            const SizedBox(height: 8),
            Text(
              '你的回答',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            SelectableText(
              answer,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _BatchHistory extends StatefulWidget {
  const _BatchHistory({required this.questions, required this.result});
  final List questions;
  final Map? result;
  @override
  State<_BatchHistory> createState() => _BatchHistoryState();
}

class _BatchHistoryState extends State<_BatchHistory> {
  late QuestionBatchController _controller;
  void _load() {
    _controller = QuestionBatchController(
      QuestionBatch(widget.questions),
      answers: {
        for (final answer in widget.result?['answers'] as List? ?? const [])
          answer['id'] as String: answer,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_BatchHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.dispose();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => QuestionBatchForm(
    controller: _controller,
    readOnly: true,
    status: widget.result?['awaitingResponse'] == true
        ? '已发送问题卡片'
        : widget.result?['answers'] != null
        ? '已回答'
        : widget.result?['skipped'] == true
        ? '已跳过'
        : widget.result?['cancelled'] == true
        ? '已取消'
        : '待回答',
  );
}
