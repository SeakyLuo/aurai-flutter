import 'package:flutter/material.dart';

import '../../domain/question_batch.dart';
import 'interactive_message_button.dart';
import 'question_batch_form.dart';
import 'question_message_heading.dart';
import 'question_icon.dart';
import 'question_options_sheet.dart';
import 'question_sheet.dart';
import 'settings_icon.dart';

/// Keep small questionnaires in chat; longer ones share the same draft in a sheet.
class QuestionnaireForm extends StatelessWidget {
  const QuestionnaireForm({
    super.key,
    required this.controller,
    required this.compact,
    required this.readOnly,
    required this.closeWhen,
    required this.onSubmit,
  });

  final QuestionBatchController controller;
  final bool compact, readOnly;
  final Future<void> closeWhen;
  final Future<void> Function() onSubmit;

  String _answerText(Map question) {
    final answer = controller.answers[question['id']] as Map?;
    if (answer == null) return question['mode'] == 'text' ? '填写回答' : '请选择';
    if (answer['skipped'] == true) return '已跳过';
    final text = answer['text'] as String? ?? '';
    if (text.isNotEmpty) return text;
    final selected = (answer['selected'] as List? ?? const []).toSet();
    return (question['options'] as List)
        .where((option) => selected.contains(option['id']))
        .map((option) => option['label'])
        .join('、');
  }

  Future<void> _edit(
    BuildContext context,
    Map<String, Object?> question,
  ) async {
    final id = question['id'] as String;
    final editor = QuestionBatchController(
      QuestionBatch([question]),
      answers: {if (controller.answers[id] != null) id: controller.answers[id]},
    );
    try {
      await showQuestionSheet(
        context,
        closeWhen: closeWhen,
        child: Builder(
          builder: (sheetContext) => QuestionSheetLayout(
            title: '填写回答',
            heading: const SizedBox.shrink(),
            child: QuestionBatchForm(
              controller: editor,
              compact: false,
              closeWhen: closeWhen,
              submitLabel: '完成',
              onSubmit: () async {
                // Completing one field updates the draft, not the questionnaire submission.
                controller.index = controller.batch.questions.indexWhere(
                  (q) => q['id'] == id,
                );
                controller.answer(
                  Map<String, Object?>.from(editor.answers[id] as Map),
                );
                Navigator.of(sheetContext).pop();
              },
            ),
          ),
        ),
      );
    } finally {
      editor.dispose();
    }
  }

  Future<void> _open(BuildContext context) => showQuestionSheet(
    context,
    closeWhen: closeWhen,
    child: QuestionSheetLayout(
      title: '填写问卷',
      icon: QuestionIconType.questionnaire,
      child: QuestionnaireForm(
        controller: controller,
        compact: false,
        readOnly: readOnly,
        closeWhen: closeWhen,
        onSubmit: onSubmit,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final questions = controller.batch.questions;
      final busy = controller.sending;
      if (questions.length == 1) {
        final question = questions.single;
        if (compact && (question['options'] as List).length > 4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QuestionMessageHeading(
                title: question['question'] as String,
                description: question['description'] as String? ?? '',
                multiple: question['mode'] == 'multiple',
                status: '',
              ),
              const SizedBox(height: 12),
              QuestionOptionsField(
                label: '去填写',
                onTap: readOnly || busy ? null : () => _open(context),
              ),
            ],
          );
        }
        return QuestionBatchForm(
          controller: controller,
          compact: compact,
          readOnly: readOnly,
          closeWhen: closeWhen,
          onSubmit: onSubmit,
        );
      }
      final filled = questions
          .where(
            (question) => controller.batch.accepts(
              question,
              controller.answers[question['id']] as Map? ?? const {},
            ),
          )
          .length;
      if (compact && questions.length > 4) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '共 ${questions.length} 题 · 已填写 $filled 题',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            QuestionOptionsField(
              label: filled == 0 ? '去填写' : '继续填写',
              onTap: readOnly || busy ? null : () => _open(context),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, question) in questions.indexed) ...[
            if (index > 0) const SizedBox(height: 16),
            Text(
              '${question['question']}${question['required'] == false ? '（选填）' : ''}',
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if ((question['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                question['description'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            QuestionOptionsField(
              label: _answerText(question),
              arrow: SettingsIconType.chevronDown,
              maxLines: 2,
              onTap: readOnly || busy ? null : () => _edit(context, question),
            ),
          ],
          if (!readOnly) ...[
            const SizedBox(height: 16),
            InteractiveMessageButton(
              button: const {'label': '提交回答', 'style': 'primary'},
              busy: busy,
              locked: busy || !controller.complete,
              onPressed: onSubmit,
            ),
          ],
        ],
      );
    },
  );
}
